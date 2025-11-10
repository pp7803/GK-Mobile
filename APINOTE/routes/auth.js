const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');
const { body, validationResult } = require('express-validator');
const { pool } = require('../config/database');
const otpService = require('../services/otpService');

const router = express.Router();

const emailLimiter = rateLimit({
    windowMs: 30 * 60 * 1000,
    max: 10,
    message: {
        error: 1,
        success: false,
        message: 'Quá nhiều email gửi từ IP này, vui lòng thử lại sau 30 phút',
    },
    standardHeaders: true,
    legacyHeaders: false,
});

/**
 * Register new user account
 * @route POST /api/auth/register
 * @param {string} req.body.email - User email address
 * @param {string} req.body.password - User password (min 6 characters)
 * @returns {Object} 201 - User created with JWT token
 * @returns {Object} 400 - Validation error or user exists
 * @returns {Object} 500 - Server error
 */
router.post(
    '/register',
    [body('email').isEmail().normalizeEmail(), body('password').isLength({ min: 6 })],
    async (req, res) => {
        try {
            const errors = validationResult(req);
            if (!errors.isEmpty()) {
                return res.status(400).json({ errors: errors.array() });
            }

            const { email, password } = req.body;

            const [existingUsers] = await pool.execute('SELECT id FROM users WHERE email = ?', [email]);

            if (existingUsers.length > 0) {
                return res.status(400).json({ message: 'User already exists' });
            }

            const salt = await bcrypt.genSalt(10);
            const hashedPassword = await bcrypt.hash(password, salt);

            const [result] = await pool.execute('INSERT INTO users (email, password) VALUES (?, ?)', [
                email,
                hashedPassword,
            ]);

            const token = jwt.sign({ userId: result.insertId, email }, process.env.JWT_SECRET, {
                expiresIn: process.env.JWT_EXPIRES_IN,
            });

            res.status(201).json({
                message: 'User created successfully',
                token,
                user: { id: result.insertId, email },
            });
        } catch (error) {
            console.error('Register error:', error);
            res.status(500).json({ message: 'Server error' });
        }
    }
);

/**
 * Login to existing account
 * @route POST /api/auth/login
 * @param {string} req.body.email - User email address
 * @param {string} req.body.password - User password
 * @returns {Object} 200 - Login successful with JWT token
 * @returns {Object} 400 - Invalid credentials or validation error
 * @returns {Object} 500 - Server error
 */
router.post('/login', [body('email').isEmail().normalizeEmail(), body('password').exists()], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const { email, password } = req.body;

        const [users] = await pool.execute('SELECT id, email, password FROM users WHERE email = ?', [email]);

        if (users.length === 0) {
            return res.status(400).json({ message: 'Invalid credentials' });
        }

        const user = users[0];

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(400).json({ message: 'Invalid credentials' });
        }

        const token = jwt.sign({ userId: user.id, email: user.email }, process.env.JWT_SECRET, {
            expiresIn: process.env.JWT_EXPIRES_IN,
        });

        res.json({
            message: 'Login successful',
            token,
            user: { id: user.id, email: user.email },
        });
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

/**
 * Request password reset OTP
 * @route POST /api/auth/forgot-password
 * @param {string} req.body.email - User email address
 * @returns {Object} 200 - OTP sent successfully
 * @returns {Object} 400 - Validation error or user not found
 * @returns {Object} 429 - Too many requests, must wait
 * @returns {Object} 500 - Server error
 */
router.post('/forgot-password', [emailLimiter, body('email').isEmail().normalizeEmail()], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const { email } = req.body;
        console.log(`Password reset requested for: ${email}`);

        const otpStatus = await otpService.getOTPStatus(email, 'reset_password');

        if (otpStatus.hasActiveOTP) {
            const remainingMinutes = Math.ceil(otpStatus.remainingSeconds / 60);
            return res.status(429).json({
                message: `Vui lòng chờ ${remainingMinutes} phút trước khi yêu cầu mã OTP mới`,
                remainingSeconds: otpStatus.remainingSeconds,
            });
        }

        const result = await otpService.createAndSendOTP(email, 'reset_password');

        if (result.success) {
            res.json({
                message: result.message,
                expiresAt: result.expiresAt,
            });
        } else {
            res.status(400).json({ message: result.message });
        }
    } catch (error) {
        console.error('Forgot password error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

/**
 * Verify OTP code for password reset
 * @route POST /api/auth/verify-otp
 * @param {string} req.body.email - User email address
 * @param {string} req.body.otp - 6-digit OTP code
 * @returns {Object} 200 - OTP verified, reset token provided
 * @returns {Object} 400 - Invalid OTP or validation error
 * @returns {Object} 500 - Server error
 */
router.post(
    '/verify-otp',
    [body('email').isEmail().normalizeEmail(), body('otp').isLength({ min: 6, max: 6 }).isNumeric()],
    async (req, res) => {
        try {
            const errors = validationResult(req);
            if (!errors.isEmpty()) {
                return res.status(400).json({ errors: errors.array() });
            }

            const { email, otp } = req.body;
            console.log(`OTP verification attempted for: ${email}`);

            const result = await otpService.verifyOTP(email, otp, 'reset_password');

            if (result.success) {
                const resetToken = jwt.sign(
                    {
                        userId: result.userId,
                        email: result.email,
                        purpose: 'reset_password',
                    },
                    process.env.JWT_SECRET,
                    { expiresIn: '15m' }
                );

                res.json({
                    message: result.message,
                    resetToken,
                    expiresIn: '15m',
                });
            } else {
                res.status(400).json({ message: result.message });
            }
        } catch (error) {
            console.error('Verify OTP error:', error);
            res.status(500).json({ message: 'Server error' });
        }
    }
);

/**
 * Reset password with verified token
 * @route POST /api/auth/reset-password
 * @param {string} req.body.resetToken - JWT reset token from OTP verification
 * @param {string} req.body.newPassword - New password (min 6 characters)
 * @returns {Object} 200 - Password reset successful
 * @returns {Object} 400 - Invalid token or validation error
 * @returns {Object} 500 - Server error
 */
router.post(
    '/reset-password',
    [body('resetToken').exists(), body('newPassword').isLength({ min: 6 })],
    async (req, res) => {
        try {
            const errors = validationResult(req);
            if (!errors.isEmpty()) {
                return res.status(400).json({ errors: errors.array() });
            }

            const { resetToken, newPassword } = req.body;

            let decoded;
            try {
                decoded = jwt.verify(resetToken, process.env.JWT_SECRET);

                if (decoded.purpose !== 'reset_password') {
                    return res.status(400).json({ message: 'Invalid reset token' });
                }
            } catch (jwtError) {
                console.error('Reset token verification error:', jwtError);
                return res.status(400).json({ message: 'Invalid or expired reset token' });
            }

            const salt = await bcrypt.genSalt(10);
            const hashedPassword = await bcrypt.hash(newPassword, salt);

            const [result] = await pool.execute(
                'UPDATE users SET password = ?, updated_at = NOW() WHERE id = ? AND email = ?',
                [hashedPassword, decoded.userId, decoded.email]
            );

            if (result.affectedRows === 0) {
                return res.status(400).json({ message: 'User not found' });
            }

            console.log(`Password reset successfully for user ${decoded.userId} (${decoded.email})`);

            res.json({
                message: 'Mật khẩu đã được đặt lại thành công. Vui lòng đăng nhập với mật khẩu mới.',
            });
        } catch (error) {
            console.error('Reset password error:', error);
            res.status(500).json({ message: 'Server error' });
        }
    }
);

/**
 * Check OTP status for user
 * @route POST /api/auth/otp-status
 * @param {string} req.body.email - User email address
 * @returns {Object} 200 - OTP status information
 * @returns {Object} 400 - Validation error
 * @returns {Object} 500 - Server error
 */
router.post('/otp-status', [body('email').isEmail().normalizeEmail()], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }

        const { email } = req.body;
        const otpStatus = await otpService.getOTPStatus(email, 'reset_password');

        res.json(otpStatus);
    } catch (error) {
        console.error('OTP status error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router;
