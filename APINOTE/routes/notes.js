const express = require('express');
const { body, validationResult } = require('express-validator');
const { pool } = require('../config/database');
const authMiddleware = require('../middleware/auth');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs').promises;
const path = require('path');

const router = express.Router();

/**
 * Read RTF content from file
 * @param {string} contentPath - Relative path to RTF file
 * @returns {Promise<string>} RTF content or empty string if error
 */
async function readRTFContent(contentPath) {
    if (!contentPath) return '';

    try {
        const fullPath = path.join(__dirname, '..', contentPath);
        const content = await fs.readFile(fullPath, 'utf8');
        return content;
    } catch (error) {
        console.error('Error reading RTF file:', error);
        return '';
    }
}

/**
 * Write RTF content to file
 * @param {string} noteId - Note UUID
 * @param {string} content - RTF content to write
 * @returns {Promise<string>} Relative path to saved file
 * @throws {Error} If write operation fails
 */
async function writeRTFContent(noteId, content) {
    const fileName = `${noteId}.rtf`;
    const relativePath = `uploads/notes/${fileName}`;
    const fullPath = path.join(__dirname, '..', relativePath);

    try {
        const dir = path.dirname(fullPath);
        await fs.mkdir(dir, { recursive: true });

        await fs.writeFile(fullPath, content || '', 'utf8');
        return relativePath;
    } catch (error) {
        console.error('Error writing RTF file:', error);
        throw error;
    }
}

/**
 * Delete RTF file from filesystem
 * @param {string} contentPath - Relative path to RTF file
 * @returns {Promise<void>}
 */
async function deleteRTFContent(contentPath) {
    if (!contentPath) return;

    try {
        const fullPath = path.join(__dirname, '..', contentPath);
        await fs.unlink(fullPath);
    } catch (error) {
        console.error('Error deleting RTF file:', error);
    }
}

/**
 * Get note content from RTF file
 * @param {Object} note - Note object with content_path
 * @returns {Promise<string>} Note content
 */
async function getNoteContent(note) {
    if (note.content_path) {
        return await readRTFContent(note.content_path);
    }
    return '';
}

/**
 * Convert date value to UTC datetime string
 * @param {Date|string|number} value - Date value to convert
 * @returns {string|null} Formatted datetime string or null
 */
function toUtcDateTimeString(value) {
    if (!value) return null;

    let dateValue;
    if (value instanceof Date) {
        dateValue = value;
    } else if (typeof value === 'string') {
        const trimmed = value.trim();
        if (!trimmed) return null;
        const isoLike = trimmed.includes('T') ? trimmed : trimmed.replace(' ', 'T');
        const normalized = /[zZ]|[+-]\d{2}:?\d{2}$/.test(isoLike) ? isoLike : `${isoLike}Z`;
        dateValue = new Date(normalized);
    } else {
        dateValue = new Date(value);
    }

    if (Number.isNaN(dateValue.getTime())) {
        return null;
    }

    const adjusted = new Date(dateValue.getTime() - dateValue.getTimezoneOffset() * 60000);
    return adjusted.toISOString().slice(0, 19).replace('T', ' ');
}

/**
 * Format note object for API response
 * @param {Object} note - Note database object
 * @param {string} content - Note content
 * @returns {Object} Formatted note response
 */
function formatNoteResponse(note, content = '') {
    return {
        id: String(note.id).toLowerCase(),
        title: note.title,
        content,
        is_draft: Boolean(note.is_draft),
        temp_delete: Number(note.temp_delete) || 0,
        created_at: toUtcDateTimeString(note.created_at),
        updated_at: toUtcDateTimeString(note.updated_at),
        synced_at: toUtcDateTimeString(note.synced_at),
    };
}

/**
 * Build complete note response with content
 * @param {Object} note - Note database object
 * @returns {Promise<Object>} Complete note response
 */
async function buildNoteResponse(note) {
    const content = await getNoteContent(note);
    return formatNoteResponse(note, content);
}

/**
 * Parse client timestamp to Date object
 * @param {Date|string|number} value - Timestamp value
 * @param {Date} fallback - Fallback date if parsing fails
 * @returns {Date} Parsed date object
 */
function parseClientTimestamp(value, fallback = new Date()) {
    if (!value) return new Date(fallback);
    if (value instanceof Date) return value;

    const trimmed = String(value).trim();
    if (!trimmed) {
        return new Date(fallback);
    }

    const isoLike = trimmed.includes('T') ? trimmed : trimmed.replace(' ', 'T');
    const normalized = /[zZ]|[+-]\d{2}:?\d{2}$/.test(isoLike) ? isoLike : `${isoLike}Z`;
    const parsed = new Date(normalized);
    if (Number.isNaN(parsed.getTime())) {
        return new Date(fallback);
    }
    return parsed;
}

/**
 * Get all notes for authenticated user
 * @route GET /api/notes
 * @param {string} req.query.include_deleted - Include soft-deleted notes ('true'/'false')
 * @returns {Object} 200 - List of notes
 * @returns {Object} 500 - Server error
 */
router.get('/', authMiddleware, async (req, res) => {
    try {
        const includeDeleted = req.query.include_deleted === 'true';

        let query =
            'SELECT id, title, content_path, is_draft, temp_delete, created_at, updated_at, synced_at FROM notes WHERE user_id = ?';

        if (!includeDeleted) {
            query += ' AND temp_delete = 0';
        }

        query += ' ORDER BY updated_at DESC';

        const [result] = await pool.query(query, [req.user.userId]);

        const notes = await Promise.all(result.map((note) => buildNoteResponse(note)));

        res.json({ notes });
    } catch (error) {
        console.error('Error fetching notes:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

/**
 * Get a single note by ID
 * @route GET /api/notes/:id
 * @param {string} req.params.id - Note ID
 * @returns {Object} 200 - Note details with content
 * @returns {Object} 404 - Note not found
 * @returns {Object} 500 - Server error
 */
router.get('/:id', authMiddleware, async (req, res) => {
    try {
        const [notes] = await pool.execute(
            'SELECT id, title, content_path, is_draft, temp_delete, created_at, updated_at, synced_at FROM notes WHERE LOWER(id) = LOWER(?) AND user_id = ?',
            [req.params.id, req.user.userId]
        );

        if (notes.length === 0) {
            return res.status(404).json({ message: 'Note not found' });
        }

        const note = notes[0];
        const payload = await buildNoteResponse(note);

        res.json(payload);
    } catch (error) {
        console.error('Get note error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

/**
 * Create a new note or update existing note with client-provided ID
 * @route POST /api/notes
 * @param {string} req.body.title - Note title (required)
 * @param {string} req.body.content - Note content in HTML format (optional)
 * @param {boolean} req.body.is_draft - Draft status (optional)
 * @param {string} req.body.id - Client-provided note ID (optional, generates UUID if not provided)
 * @returns {Object} 201 - Created/updated note
 * @returns {Object} 400 - Validation error
 * @returns {Object} 500 - Server error
 */
router.post(
    '/',
    [
        authMiddleware,
        body('title').trim().isLength({ min: 1 }),
        body('content').optional(),
        body('is_draft').optional().isBoolean(),
    ],
    async (req, res) => {
        try {
            const errors = validationResult(req);
            if (!errors.isEmpty()) {
                return res.status(400).json({ errors: errors.array() });
            }

            const { title, content = '', is_draft = false, id: clientId } = req.body;
            const noteId = clientId ? String(clientId).toLowerCase() : uuidv4().toLowerCase();

            // Write content to RTF file
            const contentPath = await writeRTFContent(noteId, content);

            // Insert to database with RTF path
            await pool.execute(
                `INSERT INTO notes (id, user_id, title, content_path, is_draft, temp_delete, synced_at)
         VALUES (?, ?, ?, ?, ?, 0, NOW())
         ON DUPLICATE KEY UPDATE title = VALUES(title), content_path = VALUES(content_path), is_draft = VALUES(is_draft), temp_delete = 0, synced_at = NOW()`,
                [noteId, req.user.userId, title, contentPath, is_draft]
            );

            const [newNote] = await pool.execute(
                'SELECT id, title, content_path, is_draft, temp_delete, created_at, updated_at, synced_at FROM notes WHERE id = ?',
                [noteId]
            );

            const payload = await buildNoteResponse(newNote[0]);

            res.status(201).json(payload);
        } catch (error) {
            console.error('Create note error:', error);
            res.status(500).json({ message: 'Server error' });
        }
    }
);

/**
 * Update an existing note
 * @route PUT /api/notes/:id
 * @param {string} req.params.id - Note ID
 * @param {string} req.body.title - Updated note title (optional)
 * @param {string} req.body.content - Updated note content in HTML format (optional)
 * @param {boolean} req.body.is_draft - Updated draft status (optional)
 * @returns {Object} 200 - Updated note
 * @returns {Object} 400 - Validation error
 * @returns {Object} 404 - Note not found
 * @returns {Object} 500 - Server error
 */
router.put(
    '/:id',
    [
        authMiddleware,
        body('title').optional().trim().isLength({ min: 1 }),
        body('content').optional(),
        body('is_draft').optional().isBoolean(),
    ],
    async (req, res) => {
        try {
            const errors = validationResult(req);
            if (!errors.isEmpty()) {
                return res.status(400).json({ errors: errors.array() });
            }

            const { title, content, is_draft } = req.body;

            // Check if note exists
            const [existingNotes] = await pool.execute(
                'SELECT id, content_path FROM notes WHERE LOWER(id) = LOWER(?) AND user_id = ?',
                [req.params.id, req.user.userId]
            );

            if (existingNotes.length === 0) {
                return res.status(404).json({ message: 'Note not found' });
            }

            const existingNote = existingNotes[0];
            let updates = [];
            let values = [];

            if (title !== undefined) {
                updates.push('title = ?');
                values.push(title);
            }

            if (content !== undefined) {
                // Update RTF file content
                await writeRTFContent(existingNote.id, content);
            }

            if (is_draft !== undefined) {
                updates.push('is_draft = ?');
                values.push(is_draft);
            }

            if (updates.length > 0) {
                updates.push('updated_at = NOW()');
                values.push(req.params.id, req.user.userId);

                await pool.execute(
                    `UPDATE notes SET ${updates.join(', ')} WHERE LOWER(id) = LOWER(?) AND user_id = ?`,
                    values
                );
            }

            const [updatedNote] = await pool.execute(
                'SELECT id, title, content_path, is_draft, temp_delete, created_at, updated_at, synced_at FROM notes WHERE LOWER(id) = LOWER(?)',
                [req.params.id]
            );

            const payload = await buildNoteResponse(updatedNote[0]);

            res.json(payload);
        } catch (error) {
            console.error('Update note error:', error);
            res.status(500).json({ message: 'Server error' });
        }
    }
);

/**
 * Soft delete a note (moves to trash)
 * @route DELETE /api/notes/:id
 * @param {string} req.params.id - Note ID
 * @returns {Object} 200 - Success message
 * @returns {Object} 404 - Note not found
 * @returns {Object} 500 - Server error
 */
router.delete('/:id', authMiddleware, async (req, res) => {
    try {
        const [notes] = await pool.execute(
            'SELECT id, title, content_path, temp_delete, created_at, updated_at FROM notes WHERE LOWER(id) = LOWER(?) AND user_id = ?',
            [req.params.id, req.user.userId]
        );

        if (notes.length === 0) {
            return res.status(404).json({ message: 'Note not found' });
        }

        // Mark as temporarily deleted
        await pool.execute(
            'UPDATE notes SET temp_delete = 1, updated_at = NOW() WHERE LOWER(id) = LOWER(?) AND user_id = ?',
            [req.params.id, req.user.userId]
        );

        res.json({ message: 'Note moved to trash' });
    } catch (error) {
        console.error('Delete note error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

/**
 * Get all deleted notes (in trash)
 * @route GET /api/notes/trash/all
 * @returns {Object} 200 - List of deleted notes with content
 * @returns {Object} 500 - Server error
 */
router.get('/trash/all', authMiddleware, async (req, res) => {
    try {
        const [result] = await pool.query(
            'SELECT id, title, content_path, updated_at as deleted_at, created_at, updated_at, synced_at FROM notes WHERE user_id = ? AND temp_delete = 1 ORDER BY updated_at DESC',
            [req.user.userId]
        );

        // Process deleted notes with RTF content
        const notesWithContent = await Promise.all(
            result.map(async (note) => {
                const content = await getNoteContent(note);
                return {
                    id: note.id,
                    title: note.title,
                    content: content,
                    deleted_at: toUtcDateTimeString(note.deleted_at),
                    original_created_at: toUtcDateTimeString(note.created_at),
                    original_updated_at: toUtcDateTimeString(note.updated_at),
                    synced_at: toUtcDateTimeString(note.synced_at),
                };
            })
        );

        res.json(notesWithContent);
    } catch (error) {
        console.error('Get deleted notes error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

/**
 * Restore a note from trash
 * @route POST /api/notes/trash/:id/restore
 * @param {string} req.params.id - Note ID
 * @returns {Object} 200 - Success message
 * @returns {Object} 404 - Deleted note not found
 * @returns {Object} 500 - Server error
 */
router.post('/trash/:id/restore', authMiddleware, async (req, res) => {
    try {
        const [notes] = await pool.execute(
            'SELECT id, title, content_path, temp_delete FROM notes WHERE LOWER(id) = LOWER(?) AND user_id = ? AND temp_delete = 1',
            [req.params.id, req.user.userId]
        );

        if (notes.length === 0) {
            return res.status(404).json({ message: 'Deleted note not found' });
        }

        // Restore note by setting temp_delete = 0
        await pool.execute(
            'UPDATE notes SET temp_delete = 0, updated_at = NOW() WHERE LOWER(id) = LOWER(?) AND user_id = ?',
            [req.params.id, req.user.userId]
        );

        res.json({ message: 'Note restored successfully' });
    } catch (error) {
        console.error('Restore note error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

/**
 * Permanently delete a note from trash
 * @route DELETE /api/notes/trash/:id
 * @param {string} req.params.id - Note ID
 * @returns {Object} 200 - Success message
 * @returns {Object} 404 - Deleted note not found
 * @returns {Object} 500 - Server error
 */
router.delete('/trash/:id', authMiddleware, async (req, res) => {
    try {
        const [notes] = await pool.execute(
            'SELECT content_path FROM notes WHERE LOWER(id) = LOWER(?) AND user_id = ? AND temp_delete = 1',
            [req.params.id, req.user.userId]
        );

        if (notes.length === 0) {
            return res.status(404).json({ message: 'Deleted note not found' });
        }

        const note = notes[0];

        // Delete RTF file if exists
        if (note.content_path) {
            await deleteRTFContent(note.content_path);
        }

        // Remove from notes table
        await pool.execute('DELETE FROM notes WHERE LOWER(id) = LOWER(?) AND user_id = ?', [
            req.params.id,
            req.user.userId,
        ]);

        res.json({ message: 'Note permanently deleted' });
    } catch (error) {
        console.error('Permanent delete error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

/**
 * Sync notes between client and server
 * @route POST /api/notes/sync
 * @param {Array} req.body.notes - Array of client notes to sync
 * @param {string} req.body.lastSyncTime - Client's last sync timestamp
 * @returns {Object} 200 - Server notes and sync timestamp
 * @returns {Object} 500 - Server error
 */
router.post('/sync', authMiddleware, async (req, res) => {
    try {
        const { notes = [], lastSyncTime } = req.body;

        // Get server notes updated after lastSyncTime
        let serverNotesQuery =
            'SELECT id, title, content_path, is_draft, temp_delete, created_at, updated_at, synced_at FROM notes WHERE user_id = ?';
        let queryParams = [req.user.userId];

        if (lastSyncTime) {
            serverNotesQuery += ' AND updated_at > ?';
            queryParams.push(parseClientTimestamp(lastSyncTime));
        }

        const [serverNotes] = await pool.execute(serverNotesQuery, queryParams);

        // Process server notes with RTF content
        const serverNotesWithContent = await Promise.all(serverNotes.map((note) => buildNoteResponse(note)));

        // Process client notes
        const conflicts = [];
        const synced = [];

        for (const clientNote of notes) {
            try {
                const normalizedClientId = clientNote.id.toLowerCase();

                // Check if note exists on server
                const [existing] = await pool.execute(
                    'SELECT id, updated_at FROM notes WHERE LOWER(id) = LOWER(?) AND user_id = ?',
                    [normalizedClientId, req.user.userId]
                );

                const normalizedCreatedAt = parseClientTimestamp(
                    clientNote.created_at,
                    clientNote.updated_at || new Date()
                );
                const normalizedUpdatedAt = parseClientTimestamp(
                    clientNote.updated_at || clientNote.created_at || new Date()
                );

                if (existing.length === 0) {
                    // Create new note
                    const contentPath = await writeRTFContent(normalizedClientId, clientNote.content || '');

                    await pool.execute(
                        `INSERT INTO notes (id, user_id, title, content_path, is_draft, temp_delete, created_at, updated_at, synced_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
                        [
                            normalizedClientId,
                            req.user.userId,
                            clientNote.title,
                            contentPath,
                            clientNote.is_draft,
                            clientNote.temp_delete || 0,
                            normalizedCreatedAt,
                            normalizedUpdatedAt,
                        ]
                    );

                    synced.push(normalizedClientId);
                } else {
                    // Update existing note
                    const contentPath = await writeRTFContent(normalizedClientId, clientNote.content || '');

                    await pool.execute(
                        `UPDATE notes SET title = ?, content_path = ?, is_draft = ?, temp_delete = ?, updated_at = ?, synced_at = NOW()
             WHERE LOWER(id) = LOWER(?) AND user_id = ?`,
                        [
                            clientNote.title,
                            contentPath,
                            clientNote.is_draft,
                            clientNote.temp_delete || 0,
                            normalizedUpdatedAt,
                            normalizedClientId,
                            req.user.userId,
                        ]
                    );

                    synced.push(normalizedClientId);
                }
            } catch (syncError) {
                console.error('Error syncing note:', syncError);
                conflicts.push({
                    noteId: clientNote.id,
                    reason: 'sync_error',
                    serverNote: null,
                });
            }
        }

        res.json({
            serverNotes: serverNotesWithContent,
            conflicts,
            synced,
            syncTime: new Date().toISOString(),
        });
    } catch (error) {
        console.error('Sync error:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router;
