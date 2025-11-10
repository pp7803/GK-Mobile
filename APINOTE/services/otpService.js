const { pool } = require('../config/database');
const emailService = require('./emailService');
require('dotenv').config();

/**
 * OTP service for generating, sending, and verifying one-time passwords
 * @class OTPService
 */
class OTPService {
    /**
     * Generate random 6-digit OTP code
     * @returns {string} 6-digit OTP code
     */
    generateOTP() {
        return Math.floor(100000 + Math.random() * 900000).toString();
    }

    /**
     * Calculate OTP expiry time based on environment config
     * @returns {Date} Expiry datetime (default 10 minutes from now)
     */
    getExpiryTime() {
        const expiryMinutes = parseInt(process.env.OTP_EXPIRES_IN?.replace('m', '') || '10');
        const expiryTime = new Date();
        expiryTime.setMinutes(expiryTime.getMinutes() + expiryMinutes);
        return expiryTime;
    }

    /**
     * Create OTP and send via email with rate limiting
     * @param {string} email - User's email address
     * @param {string} purpose - OTP purpose ('reset_password' or 'verify_email')
     * @returns {Promise<Object>} Result object with success status and message
     * @returns {boolean} return.success - Whether OTP was created and sent successfully
     * @returns {string} return.message - Success or error message
     * @returns {string} return.expiresAt - ISO timestamp when OTP expires (if success)
     * @returns {string} return.errorType - Error type if failed (RATE_LIMITED, SYSTEM_ERROR)
     * @returns {number} return.waitMinutes - Minutes to wait before next request (if rate limited)
     */
    async createAndSendOTP(email, purpose = 'reset_password') {
        try {
            const [users] = await pool.execute('SELECT id, email FROM users WHERE email = ?', [email]);

            if (users.length === 0) {
                return {
                    success: false,
                    message: 'Email không tồn tại trong hệ thống',
                };
            }

            const user = users[0];

            const [recentOTPs] = await pool.execute(
                'SELECT created_at FROM tblotp WHERE user_id = ? AND purpose = ? AND created_at > DATE_SUB(NOW(), INTERVAL 2 MINUTE) ORDER BY created_at DESC LIMIT 1',
                [user.id, purpose]
            );

            if (recentOTPs.length > 0) {
                const lastOTPTime = new Date(recentOTPs[0].created_at);
                const now = new Date();
                const timeDiff = Math.ceil((now - lastOTPTime) / 1000 / 60); // minutes
                const waitTime = Math.max(1, 2 - timeDiff);

                return {
                    success: false,
                    message: `Vui lòng chờ ${waitTime} phút trước khi yêu cầu mã OTP mới`,
                    errorType: 'RATE_LIMITED',
                    waitMinutes: waitTime,
                };
            }

            const otpCode = this.generateOTP();
            const expiresAt = this.getExpiryTime();

            await pool.execute(
                'UPDATE tblotp SET is_used = 1, used_at = NOW() WHERE user_id = ? AND purpose = ? AND is_used = 0',
                [user.id, purpose]
            );

            await pool.execute(
                'INSERT INTO tblotp (user_id, email, otp_code, purpose, expires_at) VALUES (?, ?, ?, ?, ?)',
                [user.id, email, otpCode, purpose, expiresAt]
            );

            const emailResult = await emailService.sendOTPEmail(email, otpCode, purpose);

            if (!emailResult.success) {
                if (emailResult.error === 'RATE_LIMITED') {
                    return {
                        success: false,
                        message: emailResult.msg,
                        errorType: 'RATE_LIMITED',
                    };
                }

                return {
                    success: false,
                    message: emailResult.msg || 'Không thể gửi email. Vui lòng thử lại sau.',
                };
            }

            console.log(`OTP created for user ${user.id} (${email}): ${otpCode} - expires at ${expiresAt}`);

            return {
                success: true,
                message: 'Mã OTP đã được gửi đến email của bạn',
                expiresAt: expiresAt.toISOString(),
            };
        } catch (error) {
            console.error('Create OTP error:', error);

            if (error.code === 'EENVELOPE' || error.responseCode === 450) {
                console.error('Gmail rate limiting detected for email:', email);
            }

            return {
                success: false,
                message: 'Lỗi hệ thống. Vui lòng thử lại sau.',
                errorType: error.code || 'SYSTEM_ERROR',
            };
        }
    }

    /**
     * Verify OTP code for email and purpose
     * @param {string} email - User's email address
     * @param {string} otpCode - 6-digit OTP code to verify
     * @param {string} purpose - OTP purpose ('reset_password' or 'verify_email')
     * @returns {Promise<Object>} Verification result
     * @returns {boolean} return.success - Whether OTP is valid
     * @returns {string} return.message - Success or error message
     * @returns {number} return.userId - User ID (if successful)
     * @returns {string} return.email - User email (if successful)
     */
    async verifyOTP(email, otpCode, purpose = 'reset_password') {
        try {
            console.log(`Verifying OTP: ${email} - ${otpCode} - ${purpose}`);

            const [otps] = await pool.execute(
                `SELECT o.id, o.user_id, o.expires_at, u.email 
         FROM tblotp o 
         JOIN users u ON o.user_id = u.id 
         WHERE o.email = ? AND o.otp_code = ? AND o.purpose = ? AND o.is_used = 0 AND o.expires_at > NOW()
         ORDER BY o.created_at DESC 
         LIMIT 1`,
                [email, otpCode, purpose]
            );

            if (otps.length === 0) {
                console.log('OTP not found or expired');
                return {
                    success: false,
                    message: 'Mã OTP không hợp lệ hoặc đã hết hạn',
                };
            }

            const otp = otps[0];

            await pool.execute('UPDATE tblotp SET is_used = 1, used_at = NOW() WHERE id = ?', [otp.id]);

            console.log(`OTP verified successfully for user ${otp.user_id}`);

            return {
                success: true,
                message: 'Mã OTP hợp lệ',
                userId: otp.user_id,
                email: otp.email,
            };
        } catch (error) {
            console.error('Verify OTP error:', error);
            return { success: false, message: 'Lỗi hệ thống. Vui lòng thử lại sau.' };
        }
    }

    /**
     * Clean up expired and used OTPs from database
     * @returns {Promise<number>} Number of deleted OTP records
     */
    async cleanupExpiredOTPs() {
        try {
            const [result] = await pool.execute(
                'DELETE FROM tblotp WHERE expires_at < NOW() OR (is_used = 1 AND used_at < DATE_SUB(NOW(), INTERVAL 1 DAY))'
            );

            console.log(`Cleaned up ${result.affectedRows} expired/used OTPs`);
            return result.affectedRows;
        } catch (error) {
            console.error('Cleanup OTPs error:', error);
            return 0;
        }
    }

    /**
     * Get active OTP status for user
     * @param {string} email - User's email address
     * @param {string} purpose - OTP purpose ('reset_password' or 'verify_email')
     * @returns {Promise<Object>} OTP status information
     * @returns {boolean} return.hasActiveOTP - Whether user has an active OTP
     * @returns {string} return.expiresAt - When OTP expires (if active)
     * @returns {number} return.remainingSeconds - Seconds until expiry (if active)
     * @returns {string} return.createdAt - When OTP was created (if active)
     */
    async getOTPStatus(email, purpose = 'reset_password') {
        try {
            const [otps] = await pool.execute(
                `SELECT expires_at, created_at FROM tblotp 
         WHERE email = ? AND purpose = ? AND is_used = 0 AND expires_at > NOW()
         ORDER BY created_at DESC 
         LIMIT 1`,
                [email, purpose]
            );

            if (otps.length === 0) {
                return { hasActiveOTP: false };
            }

            const otp = otps[0];
            const now = new Date();
            const expiresAt = new Date(otp.expires_at);
            const remainingTime = Math.max(0, Math.floor((expiresAt - now) / 1000));

            return {
                hasActiveOTP: true,
                expiresAt: otp.expires_at,
                remainingSeconds: remainingTime,
                createdAt: otp.created_at,
            };
        } catch (error) {
            console.error('Get OTP status error:', error);
            return { hasActiveOTP: false };
        }
    }
}

module.exports = new OTPService();
