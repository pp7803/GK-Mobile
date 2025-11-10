const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const path = require('path');
require('dotenv').config();

const authRoutes = require('./routes/auth');
const notesRoutes = require('./routes/notes');

const app = express();
const PORT = process.env.PORT || 3102;

app.use(helmet());
app.use(cors());

/**
 * Rate limiting middleware - 100 requests per 15 minutes per IP
 */
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 100,
});
app.use(limiter);

app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.set('trust proxy', 1);

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

app.use('/api/auth', authRoutes);
app.use('/api/notes', notesRoutes);

/**
 * Health check endpoint
 * @route GET /api/health
 * @returns {Object} 200 - API status and version info
 */
app.get('/api/health', (req, res) => {
    res.json({
        status: 'OK',
        message: 'PPNote API is running',
        version: '1.1.0',
        features: ['notes', 'rich-content', 'images', 'tables'],
    });
});

/**
 * Global error handling middleware
 * @param {Error} err - Error object
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @param {Function} next - Next middleware
 */
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ message: 'Something went wrong!' });
});

/**
 * 404 handler for undefined routes
 */
app.use('*', (req, res) => {
    res.status(404).json({ message: 'Route not found' });
});

/**
 * Clean up expired OTPs from database
 * @returns {Promise<void>}
 */
const cleanupExpiredOTPs = async () => {
    try {
        const otpService = require('./services/otpService');
        await otpService.cleanupExpiredOTPs();
    } catch (error) {
        console.error('Error cleaning up expired OTPs:', error);
    }
};

/**
 * Schedule OTP cleanup to run every hour
 */
setInterval(() => {
    cleanupExpiredOTPs();
}, 60 * 60 * 1000);

/**
 * Initialize services and start Express server
 * @returns {Promise<void>}
 */
const startServer = async () => {
    try {
        const emailService = require('./services/emailService');
        await emailService.verifyConnection();

        app.listen(PORT, () => {
            console.log(`PPNote API server running on port ${PORT}`);
            console.log(`Environment: ${process.env.NODE_ENV}`);
        });
    } catch (error) {
        console.error('Failed to start server:', error);
        process.exit(1);
    }
};

startServer();
