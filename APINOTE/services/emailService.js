const nodemailer = require('nodemailer');
require('dotenv').config();

/**
 * Email service for sending OTP and notifications
 * @class EmailService
 */
class EmailService {
    /**
     * Initialize email transporter with SMTP configuration
     */
    constructor() {
        this.transporter = nodemailer.createTransport({
            host: process.env.HOST_EMAIL,
            port: 465,
            secure: true,
            auth: {
                user: process.env.HOST_EMAIL_USERNAME,
                pass: process.env.HOST_EMAIL_PASS,
            },
        });
    }

    /**
     * Send OTP email to user
     * @param {string} email - Recipient email address
     * @param {string} otpCode - 6-digit OTP code
     * @param {string} purpose - Email purpose ('reset_password' or 'verify_email')
     * @returns {Promise<Object>} Result object with success status and message
     * @returns {number} return.code - HTTP status code (200, 429, 500)
     * @returns {boolean} return.success - Whether email was sent successfully
     * @returns {string} return.msg - Success or error message
     * @returns {string} return.error - Error type if failed
     */
    async sendOTPEmail(email, otpCode, purpose = 'reset_password') {
        try {
            const subject =
                purpose === 'reset_password' ? 'Mã OTP đặt lại mật khẩu - PPNote' : 'Mã OTP xác thực email - PPNote';

            const htmlContent = this.generateOTPEmailHTML(otpCode, purpose);

            const mailOptions = {
                from: {
                    name: 'PPNote App',
                    address: process.env.HOST_EMAIL_USERNAME,
                },
                to: email,
                subject: subject,
                html: htmlContent,
                text: `Mã OTP của bạn là: ${otpCode}. Mã này có hiệu lực trong 10 phút. Nếu bạn không yêu cầu mã này, vui lòng bỏ qua email. Trân trọng, Đội ngũ PPNote`,
            };

            await this.transporter.sendMail(mailOptions);
            console.log(`Email sent successfully to: ${email}`);
            return { code: 200, success: true, msg: 'OK' };
        } catch (error) {
            console.error(`Failed to send OTP email to ${email}:`, error);

            if (error.responseCode === 450 || error.code === 'EENVELOPE') {
                return {
                    code: 429,
                    success: false,
                    error: 'RATE_LIMITED',
                    msg: 'Email tạm thời bị giới hạn. Vui lòng thử lại sau 5-10 phút.',
                };
            }

            return {
                code: 500,
                success: false,
                error: error.code || 'EMAIL_ERROR',
                msg: `Không thể gửi email. Lỗi: ${error.message}`,
            };
        }
    }

    /**
     * Generate HTML content for OTP email
     * @param {string} otpCode - 6-digit OTP code
     * @param {string} purpose - Email purpose ('reset_password' or 'verify_email')
     * @returns {string} HTML email content
     */
    generateOTPEmailHTML(otpCode, purpose) {
        const title = purpose === 'reset_password' ? 'Đặt lại mật khẩu' : 'Xác thực email';

        const description =
            purpose === 'reset_password'
                ? 'Bạn đã yêu cầu đặt lại mật khẩu cho tài khoản PPNote.'
                : 'Bạn đang xác thực email cho tài khoản PPNote.';

        return `
        <!DOCTYPE html>
        <html lang="vi">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>${title} - PPNote</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    max-width: 600px;
                    margin: 0 auto;
                    padding: 20px;
                    background-color: #f5f5f5;
                }
                .container {
                    background: white;
                    border-radius: 12px;
                    padding: 40px;
                    box-shadow: 0 4px 12px rgba(0,0,0,0.1);
                }
                .header {
                    text-align: center;
                    margin-bottom: 30px;
                }
                .logo {
                    font-size: 28px;
                    font-weight: bold;
                    color: #007AFF;
                    margin-bottom: 10px;
                }
                .otp-container {
                    background: #f8f9fa;
                    border: 2px dashed #007AFF;
                    border-radius: 8px;
                    padding: 20px;
                    text-align: center;
                    margin: 30px 0;
                }
                .otp-code {
                    font-size: 36px;
                    font-weight: bold;
                    color: #007AFF;
                    letter-spacing: 8px;
                    margin: 10px 0;
                    font-family: 'Courier New', monospace;
                }
                .warning {
                    background: #fff3cd;
                    border: 1px solid #ffeaa7;
                    border-radius: 6px;
                    padding: 15px;
                    margin: 20px 0;
                    color: #856404;
                }
                .footer {
                    text-align: center;
                    margin-top: 30px;
                    padding-top: 20px;
                    border-top: 1px solid #eee;
                    color: #666;
                    font-size: 14px;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <div class="logo">📝 PPNote</div>
                    <h1>${title}</h1>
                </div>
                
                <p>Xin chào,</p>
                <p>${description}</p>
                
                <div class="otp-container">
                    <p><strong>Mã OTP của bạn là:</strong></p>
                    <div class="otp-code">${otpCode}</div>
                    <p><small>Mã này có hiệu lực trong 10 phút</small></p>
                </div>
                
                <div class="warning">
                    <strong>⚠️ Lưu ý bảo mật:</strong>
                    <ul style="margin: 10px 0; padding-left: 20px;">
                        <li>Không chia sẻ mã OTP này với bất kỳ ai</li>
                        <li>PPNote sẽ không bao giờ yêu cầu mã OTP qua điện thoại</li>
                        <li>Nếu bạn không yêu cầu mã này, vui lòng bỏ qua email</li>
                    </ul>
                </div>
                
                <p>Nếu bạn gặp vấn đề gì, vui lòng liên hệ với chúng tôi.</p>
                
                <div class="footer">
                    <p>Trân trọng,<br><strong>Đội ngũ PPNote</strong></p>
                    <p><small>Email này được gửi tự động, vui lòng không trả lời.</small></p>
                </div>
            </div>
        </body>
        </html>`;
    }

    /**
     * Verify email service connection
     * @returns {Promise<boolean>} True if connection successful, false otherwise
     */
    async verifyConnection() {
        try {
            await this.transporter.verify();
            console.log('Email service is ready');
            return true;
        } catch (error) {
            console.error('Email service connection error:', error);
            return false;
        }
    }
}

module.exports = new EmailService();
