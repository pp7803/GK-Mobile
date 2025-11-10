# PPNote Backend API

Backend API cho ứng dụng PPNote - ứng dụng ghi chú với rich text editor, hỗ trợ đồng bộ, quản lý hình ảnh và xác thực người dùng.

## 📋 Mục lục

-   [Thông tin chung](#thông-tin-chung)
-   [Cài đặt](#cài-đặt)
-   [Cấu hình](#cấu-hình)
-   [API Documentation](#api-documentation)
    -   [Authentication APIs](#authentication-apis)
    -   [Notes APIs](#notes-apis)
    -   [Trash APIs](#trash-apis)
    -   [Sync APIs](#sync-apis)
-   [Database Schema](#database-schema)
-   [Error Handling](#error-handling)

## 🚀 Thông tin chung

-   **Version**: 1.1.0
-   **Port mặc định**: 3102
-   **Database**: MySQL
-   **Authentication**: JWT (JSON Web Tokens)
-   **Email Service**: Nodemailer
-   **Rate Limiting**: 100 requests/15 phút

### Features

-   ✅ User authentication (Register, Login, Password Reset)
-   ✅ OTP-based password recovery
-   ✅ Rich text notes with RTF file storage
-   ✅ Image uploads và base64 encoding
-   ✅ Soft delete (trash) functionality
-   ✅ Real-time sync across devices
-   ✅ Rate limiting và security headers
-   ✅ Email notifications

## 📦 Cài đặt

### Yêu cầu hệ thống

-   Node.js >= 14.x
-   MySQL >= 5.7
-   npm hoặc yarn

### Cài đặt dependencies

```bash
npm install
```

### Tạo database

```sql
CREATE DATABASE ppnote;

CREATE TABLE users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  email VARCHAR(255) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE notes (
  id VARCHAR(36) PRIMARY KEY,
  user_id INT NOT NULL,
  title VARCHAR(255) NOT NULL,
  content_path VARCHAR(500),
  is_draft BOOLEAN DEFAULT false,
  temp_delete TINYINT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  synced_at TIMESTAMP NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_updated (user_id, updated_at),
  INDEX idx_temp_delete (temp_delete)
);

CREATE TABLE otp_codes (
  id INT PRIMARY KEY AUTO_INCREMENT,
  email VARCHAR(255) NOT NULL,
  otp_code VARCHAR(6) NOT NULL,
  purpose VARCHAR(50) NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_email_purpose (email, purpose),
  INDEX idx_expires (expires_at)
);
```

## ⚙️ Cấu hình

Tạo file `.env` trong thư mục root:

```env
# Server Configuration
PORT=3102
NODE_ENV=development

# Database Configuration
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=ppnote
DB_PORT=3306

# JWT Configuration
JWT_SECRET=your_super_secret_key_here
JWT_EXPIRES_IN=7d

# Email Configuration (Gmail example)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_SECURE=false
EMAIL_USER=your-email@gmail.com
EMAIL_PASSWORD=your-app-password
EMAIL_FROM=PPNote <noreply@ppnote.com>

# OTP Configuration
OTP_EXPIRY_MINUTES=10
OTP_RESEND_DELAY_MINUTES=5
```

### Chạy server

```bash
# Development mode với nodemon
npm run dev

# Production mode
npm start
```

Server sẽ chạy tại `http://localhost:3102`

## 📚 API Documentation

### Base URL

```
http://localhost:3102/api
```

### Response Format

Tất cả API responses đều theo format JSON:

**Success Response:**

```json
{
  "message": "Success message",
  "data": { ... }
}
```

**Error Response:**

```json
{
  "message": "Error message",
  "errors": [ ... ] // Optional validation errors
}
```

---

## 🔐 Authentication APIs

### 1. Register

Đăng ký tài khoản mới.

**Endpoint:** `POST /api/auth/register`

**Request Body:**

```json
{
    "email": "user@example.com",
    "password": "password123"
}
```

**Validation:**

-   `email`: Valid email format, normalized
-   `password`: Minimum 6 characters

**Success Response (201):**

```json
{
    "message": "User created successfully",
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
        "id": 1,
        "email": "user@example.com"
    }
}
```

**Error Responses:**

-   `400`: User already exists / Validation errors
-   `500`: Server error

---

### 2. Login

Đăng nhập vào hệ thống.

**Endpoint:** `POST /api/auth/login`

**Request Body:**

```json
{
    "email": "user@example.com",
    "password": "password123"
}
```

**Success Response (200):**

```json
{
    "message": "Login successful",
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
        "id": 1,
        "email": "user@example.com"
    }
}
```

**Error Responses:**

-   `400`: Invalid credentials / Validation errors
-   `500`: Server error

---

### 3. Forgot Password (Request OTP)

Yêu cầu mã OTP để reset mật khẩu.

**Endpoint:** `POST /api/auth/forgot-password`

**Rate Limit:** 10 requests / 30 phút per IP

**Request Body:**

```json
{
    "email": "user@example.com"
}
```

**Success Response (200):**

```json
{
    "message": "Mã OTP đã được gửi đến email của bạn",
    "expiresAt": "2025-11-10T10:15:00.000Z"
}
```

**Error Responses:**

-   `400`: Validation errors / User not found
-   `429`: Too many requests (wait X minutes)
-   `500`: Server error

**Notes:**

-   OTP có hiệu lực trong 10 phút (mặc định)
-   Chỉ được yêu cầu OTP mới sau 5 phút kể từ lần gửi trước
-   Email chứa mã OTP 6 chữ số

---

### 4. Verify OTP

Xác thực mã OTP để reset mật khẩu.

**Endpoint:** `POST /api/auth/verify-otp`

**Request Body:**

```json
{
    "email": "user@example.com",
    "otp": "123456"
}
```

**Validation:**

-   `otp`: Exactly 6 numeric characters

**Success Response (200):**

```json
{
    "message": "OTP verified successfully",
    "resetToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": "15m"
}
```

**Error Responses:**

-   `400`: Invalid OTP / OTP expired / Validation errors
-   `500`: Server error

**Notes:**

-   `resetToken` có hiệu lực 15 phút
-   Token chỉ được dùng để reset password

---

### 5. Reset Password

Đặt lại mật khẩu mới sau khi verify OTP.

**Endpoint:** `POST /api/auth/reset-password`

**Request Body:**

```json
{
    "resetToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "newPassword": "newpassword123"
}
```

**Validation:**

-   `newPassword`: Minimum 6 characters

**Success Response (200):**

```json
{
    "message": "Mật khẩu đã được đặt lại thành công. Vui lòng đăng nhập với mật khẩu mới."
}
```

**Error Responses:**

-   `400`: Invalid/expired reset token / User not found / Validation errors
-   `500`: Server error

---

### 6. Check OTP Status

Kiểm tra xem user có thể request OTP mới không.

**Endpoint:** `POST /api/auth/otp-status`

**Request Body:**

```json
{
    "email": "user@example.com"
}
```

**Success Response (200):**

```json
{
    "hasActiveOTP": true,
    "remainingSeconds": 180,
    "canRequestNew": false
}
```

hoặc

```json
{
    "hasActiveOTP": false,
    "remainingSeconds": 0,
    "canRequestNew": true
}
```

---

## 📝 Notes APIs

**Authentication Required:** Tất cả Notes APIs yêu cầu JWT token trong header:

```
Authorization: Bearer <token>
```

### 1. Get All Notes

Lấy danh sách tất cả ghi chú của user.

**Endpoint:** `GET /api/notes`

**Query Parameters:**

-   `include_deleted` (optional): `true` để bao gồm cả notes đã xóa (soft delete)

**Success Response (200):**

```json
{
    "notes": [
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "title": "My First Note",
            "content": "<p>Rich text content...</p>",
            "is_draft": false,
            "temp_delete": 0,
            "created_at": "2025-11-10 08:00:00",
            "updated_at": "2025-11-10 09:30:00",
            "synced_at": "2025-11-10 09:30:00"
        }
    ]
}
```

**Notes:**

-   Notes được sắp xếp theo `updated_at` (mới nhất trước)
-   Mặc định không trả về notes đã soft delete (temp_delete = 1)
-   Content được đọc từ RTF file storage

---

### 2. Get Single Note

Lấy chi tiết một ghi chú.

**Endpoint:** `GET /api/notes/:id`

**URL Parameters:**

-   `id`: Note UUID

**Success Response (200):**

```json
{
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "My Note",
    "content": "<p>Full rich text content...</p>",
    "is_draft": false,
    "temp_delete": 0,
    "created_at": "2025-11-10 08:00:00",
    "updated_at": "2025-11-10 09:30:00",
    "synced_at": "2025-11-10 09:30:00"
}
```

**Error Responses:**

-   `404`: Note not found
-   `500`: Server error

---

### 3. Create Note

Tạo ghi chú mới.

**Endpoint:** `POST /api/notes`

**Request Body:**

```json
{
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "New Note Title",
    "content": "<p>Rich text content with <strong>formatting</strong></p>",
    "is_draft": false
}
```

**Validation:**

-   `title`: Required, minimum 1 character after trim
-   `content`: Optional, defaults to empty string
-   `is_draft`: Optional boolean, defaults to false
-   `id`: Optional UUID, nếu không có sẽ tự động generate

**Success Response (201):**

```json
{
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "New Note Title",
    "content": "<p>Rich text content with <strong>formatting</strong></p>",
    "is_draft": false,
    "temp_delete": 0,
    "created_at": "2025-11-10 10:00:00",
    "updated_at": "2025-11-10 10:00:00",
    "synced_at": "2025-11-10 10:00:00"
}
```

**Notes:**

-   Content được lưu vào file RTF tại `uploads/notes/{noteId}.rtf`
-   Nếu note với `id` đã tồn tại, sẽ update thay vì tạo mới (upsert)
-   `synced_at` được set tự động

**Error Responses:**

-   `400`: Validation errors
-   `500`: Server error

---

### 4. Update Note

Cập nhật ghi chú hiện có.

**Endpoint:** `PUT /api/notes/:id`

**URL Parameters:**

-   `id`: Note UUID

**Request Body:**

```json
{
    "title": "Updated Title",
    "content": "<p>Updated content...</p>",
    "is_draft": true
}
```

**Notes:**

-   Tất cả fields đều optional
-   Chỉ các fields được gửi lên mới được update
-   `updated_at` tự động được cập nhật

**Success Response (200):**

```json
{
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "Updated Title",
    "content": "<p>Updated content...</p>",
    "is_draft": true,
    "temp_delete": 0,
    "created_at": "2025-11-10 08:00:00",
    "updated_at": "2025-11-10 10:30:00",
    "synced_at": "2025-11-10 09:30:00"
}
```

**Error Responses:**

-   `400`: Validation errors
-   `404`: Note not found
-   `500`: Server error

---

### 5. Soft Delete Note

Xóa ghi chú (chuyển vào thùng rác).

**Endpoint:** `DELETE /api/notes/:id`

**URL Parameters:**

-   `id`: Note UUID

**Success Response (200):**

```json
{
    "message": "Note moved to trash"
}
```

**Notes:**

-   Đây là soft delete: set `temp_delete = 1`
-   Note vẫn tồn tại trong database
-   Có thể restore lại từ trash

**Error Responses:**

-   `404`: Note not found
-   `500`: Server error

---

## 🗑️ Trash APIs

### 1. Get Deleted Notes

Lấy danh sách các ghi chú đã xóa (trong thùng rác).

**Endpoint:** `GET /api/notes/trash/all`

**Success Response (200):**

```json
[
    {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "title": "Deleted Note",
        "content": "<p>Content of deleted note...</p>",
        "deleted_at": "2025-11-10 10:00:00",
        "original_created_at": "2025-11-10 08:00:00",
        "original_updated_at": "2025-11-10 09:30:00",
        "synced_at": "2025-11-10 09:30:00"
    }
]
```

**Notes:**

-   Chỉ trả về notes có `temp_delete = 1`
-   Được sắp xếp theo thời gian xóa (mới nhất trước)

---

### 2. Restore Note from Trash

Khôi phục ghi chú từ thùng rác.

**Endpoint:** `POST /api/notes/trash/:id/restore`

**URL Parameters:**

-   `id`: Note UUID

**Success Response (200):**

```json
{
    "message": "Note restored successfully"
}
```

**Notes:**

-   Set `temp_delete = 0`
-   Note sẽ xuất hiện lại trong danh sách notes thông thường
-   `updated_at` được cập nhật

**Error Responses:**

-   `404`: Deleted note not found
-   `500`: Server error

---

### 3. Permanently Delete Note

Xóa vĩnh viễn ghi chú khỏi database.

**Endpoint:** `DELETE /api/notes/trash/:id`

**URL Parameters:**

-   `id`: Note UUID

**Success Response (200):**

```json
{
    "message": "Note permanently deleted"
}
```

**Notes:**

-   Hard delete: xóa hoàn toàn khỏi database
-   RTF file cũng bị xóa
-   Không thể khôi phục

**Error Responses:**

-   `404`: Deleted note not found (hoặc note không ở trong trash)
-   `500`: Server error

---

## 🔄 Sync APIs

### Sync Notes

Đồng bộ ghi chú giữa client và server.

**Endpoint:** `POST /api/notes/sync`

**Request Body:**

```json
{
    "notes": [
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "title": "Note from client",
            "content": "<p>Content...</p>",
            "is_draft": false,
            "temp_delete": 0,
            "created_at": "2025-11-10T08:00:00.000Z",
            "updated_at": "2025-11-10T09:30:00.000Z"
        }
    ],
    "lastSyncTime": "2025-11-10T09:00:00.000Z"
}
```

**Request Parameters:**

-   `notes`: Array of client notes cần sync
-   `lastSyncTime`: Timestamp của lần sync cuối (optional)

**Success Response (200):**

```json
{
    "serverNotes": [
        {
            "id": "abc-def-ghi",
            "title": "Note from server",
            "content": "<p>Server content...</p>",
            "is_draft": false,
            "temp_delete": 0,
            "created_at": "2025-11-10 08:30:00",
            "updated_at": "2025-11-10 09:45:00",
            "synced_at": "2025-11-10 09:45:00"
        }
    ],
    "conflicts": [],
    "synced": ["550e8400-e29b-41d4-a716-446655440000"],
    "syncTime": "2025-11-10T10:00:00.000Z"
}
```

**Response Fields:**

-   `serverNotes`: Notes từ server (updated sau lastSyncTime)
-   `conflicts`: Array các notes bị conflict
-   `synced`: Array các note IDs đã sync thành công
-   `syncTime`: Timestamp của lần sync này

**Sync Logic:**

1. **Server → Client:**

    - Trả về tất cả notes có `updated_at > lastSyncTime`
    - Include cả deleted notes (temp_delete = 1)

2. **Client → Server:**

    - Nếu note ID không tồn tại: Create mới
    - Nếu note ID đã tồn tại: Update với timestamp từ client
    - Content được lưu vào RTF file
    - `synced_at` được set = NOW()

3. **Conflict Handling:**
    - Nếu có lỗi khi sync một note, thêm vào `conflicts` array
    - Client cần xử lý conflicts theo logic riêng

**Notes:**

-   Timestamps được normalize về UTC
-   RTF files được tạo/update tự động
-   Hỗ trợ sync cả draft và deleted notes

**Error Responses:**

-   `500`: Server error

---

## 🏥 Health Check API

**Endpoint:** `GET /api/health`

**Success Response (200):**

```json
{
    "status": "OK",
    "message": "PPNote API is running",
    "version": "1.1.0",
    "features": ["notes", "rich-content", "images", "tables"]
}
```

---

## 💾 Database Schema

### Users Table

```sql
CREATE TABLE users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  email VARCHAR(255) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### Notes Table

```sql
CREATE TABLE notes (
  id VARCHAR(36) PRIMARY KEY,           -- UUID
  user_id INT NOT NULL,
  title VARCHAR(255) NOT NULL,
  content_path VARCHAR(500),            -- Path to RTF file
  is_draft BOOLEAN DEFAULT false,
  temp_delete TINYINT DEFAULT 0,        -- 0: active, 1: in trash
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  synced_at TIMESTAMP NULL,             -- Last sync time
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_updated (user_id, updated_at),
  INDEX idx_temp_delete (temp_delete)
);
```

### OTP Codes Table

```sql
CREATE TABLE otp_codes (
  id INT PRIMARY KEY AUTO_INCREMENT,
  email VARCHAR(255) NOT NULL,
  otp_code VARCHAR(6) NOT NULL,
  purpose VARCHAR(50) NOT NULL,         -- 'reset_password'
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_email_purpose (email, purpose),
  INDEX idx_expires (expires_at)
);
```

---

## 🔒 Security Features

### Rate Limiting

-   **Global:** 100 requests / 15 phút per IP
-   **Email endpoints:** 10 requests / 30 phút per IP

### Password Security

-   Bcrypt hashing với salt rounds = 10
-   Minimum password length: 6 characters

### JWT Tokens

-   **Login token:** 7 days expiry (configurable)
-   **Reset token:** 15 minutes expiry
-   Secret key stored in environment variable

### Headers

-   Helmet.js cho security headers
-   CORS enabled
-   Trust proxy for rate limiting

---

## ⚠️ Error Handling

### HTTP Status Codes

-   `200`: Success
-   `201`: Created
-   `400`: Bad Request / Validation Error
-   `401`: Unauthorized
-   `404`: Not Found
-   `429`: Too Many Requests
-   `500`: Internal Server Error

### Error Response Format

```json
{
    "message": "Error description",
    "errors": [
        {
            "field": "email",
            "message": "Invalid email format"
        }
    ]
}
```

---

## 📁 File Storage

### RTF Files

-   **Location:** `uploads/notes/{noteId}.rtf`
-   **Format:** UTF-8 text
-   **Content:** Rich text HTML

### Upload Directory Structure

```
uploads/
├── notes/
│   ├── {uuid-1}.rtf
│   ├── {uuid-2}.rtf
│   └── ...
└── data/
```

---

## 🧹 Maintenance

### Automatic Cleanup

-   **OTP Codes:** Expired OTPs được cleanup mỗi giờ
-   **Implementation:** Background job trong `server.js`

### Manual Cleanup

```javascript
// Clean up expired OTPs
const otpService = require('./services/otpService');
await otpService.cleanupExpiredOTPs();
```

---

## 🛠️ Development

### Debug Mode

Set `NODE_ENV=development` trong `.env` để enable:

-   Chi tiết error logs
-   Stack traces
-   Development-specific features

### Testing

```bash
# Run tests (khi có)
npm test
```

### Code Structure

```
APINOTE/
├── config/
│   └── database.js         # MySQL connection pool
├── middleware/
│   └── auth.js             # JWT authentication middleware
├── routes/
│   ├── auth.js             # Authentication routes
│   └── notes.js            # Notes CRUD & sync routes
├── services/
│   ├── emailService.js     # Nodemailer email sending
│   └── otpService.js       # OTP generation & verification
├── uploads/
│   └── notes/              # RTF file storage
├── .env                    # Environment variables
├── package.json
└── server.js               # Express app entry point
```
