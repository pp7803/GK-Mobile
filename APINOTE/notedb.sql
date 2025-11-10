-- phpMyAdmin SQL Dump
-- version 5.1.1
-- https://www.phpmyadmin.net/
--
-- Máy chủ: localhost
-- Thời gian đã tạo: Th10 11, 2025 lúc 12:54 AM
-- Phiên bản máy phục vụ: 8.0.35
-- Phiên bản PHP: 7.4.33

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Cơ sở dữ liệu: `notedb`
--

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `notes`
--

CREATE TABLE `notes` (
  `id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` int DEFAULT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_draft` tinyint(1) DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `synced_at` timestamp NULL DEFAULT NULL,
  `content_path` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `temp_delete` tinyint DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `notes`
--

INSERT INTO `notes` (`id`, `user_id`, `title`, `is_draft`, `created_at`, `updated_at`, `synced_at`, `content_path`, `temp_delete`) VALUES
('1706da08-8fd4-4bc9-ab80-35f36a6232c5', 2, 'Proxy vs. VPN: So sánh Chi Tiết', 0, '2025-10-28 01:19:02', '2025-10-28 01:19:02', '2025-10-28 01:44:15', 'uploads/notes/1706da08-8fd4-4bc9-ab80-35f36a6232c5.rtf', 0),
('1988bf4d-eeba-45f3-bffb-3e5ee25a8a34', 2, 'Lịch trình làm việc của Kỹ sư Mạng máy tính', 0, '2025-10-25 03:52:52', '2025-10-28 01:18:20', '2025-10-28 01:44:15', 'uploads/notes/1988bf4d-eeba-45f3-bffb-3e5ee25a8a34.rtf', 0),
('22dd42f6-24a6-48c5-a604-c7122570551c', 2, '1', 0, '2025-10-30 18:56:27', '2025-11-08 11:11:47', '2025-11-08 11:11:50', 'uploads/notes/22dd42f6-24a6-48c5-a604-c7122570551c.rtf', 0),
('55508c83-cf96-4e06-b967-64014722dc2b', 2, 'Copy of Lịch trình làm việc của Kỹ sư Mạng máy tính', 1, '2025-11-10 16:34:02', '2025-11-10 16:34:02', '2025-11-10 16:34:23', 'uploads/notes/55508c83-cf96-4e06-b967-64014722dc2b.rtf', 0),
('87e26c88-824b-494d-8388-e717eb15389e', 2, 'Hole', 1, '2025-10-28 08:44:30', '2025-11-08 11:11:39', '2025-11-08 11:11:50', 'uploads/notes/87e26c88-824b-494d-8388-e717eb15389e.rtf', 0);

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `tblotp`
--

CREATE TABLE `tblotp` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `email` varchar(255) NOT NULL,
  `otp_code` varchar(6) NOT NULL,
  `purpose` enum('reset_password','email_verification') NOT NULL DEFAULT 'reset_password',
  `is_used` tinyint(1) DEFAULT '0',
  `expires_at` timestamp NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `used_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

-- --------------------------------------------------------

--
-- Cấu trúc bảng cho bảng `users`
--

CREATE TABLE `users` (
  `id` int NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Đang đổ dữ liệu cho bảng `users`
--

INSERT INTO `users` (`id`, `email`, `password`, `created_at`, `updated_at`) VALUES
(1, 'duyphtpham783@gmail.com', '$2a$10$Wm3.1R4k1Q/qRVC/pVD3XO3TkeJh1Fmo6kNN8trOq/kXKzSImX6By', '2025-10-22 09:53:15', '2025-10-22 09:53:15'),
(2, 'duyphatpham783@gmail.com', '$2a$10$nnVQsPcf5jQ4YXolbXbf5OPgY.ll7P/JOs/IK2mkd/LnDcKNXCFv.', '2025-10-22 12:02:08', '2025-10-22 12:02:08'),
(3, 'duyphat8d@gmail.com', '$2a$10$t4jQis9OMll1YLXDxo5Iou7GvNdzvIdzSzxX7cPDbBGQRTLsQPT6e', '2025-10-22 16:35:04', '2025-10-22 16:39:21'),
(4, 'phgthao2106@gmail.com', '$2a$10$8PaahohvayXNlDl//96bmOgm4F4zTRIJ3wknYVHsS8phjNXBiPA2y', '2025-10-22 20:44:20', '2025-10-22 20:51:27');

--
-- Chỉ mục cho các bảng đã đổ
--

--
-- Chỉ mục cho bảng `notes`
--
ALTER TABLE `notes`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user_updated` (`user_id`,`updated_at`),
  ADD KEY `idx_synced` (`synced_at`),
  ADD KEY `idx_notes_rich_content` (`updated_at`),
  ADD KEY `idx_notes_temp_delete` (`temp_delete`),
  ADD KEY `idx_notes_user_temp_delete` (`user_id`,`temp_delete`);

--
-- Chỉ mục cho bảng `tblotp`
--
ALTER TABLE `tblotp`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_email_otp` (`email`,`otp_code`),
  ADD KEY `idx_expires` (`expires_at`),
  ADD KEY `idx_user_purpose` (`user_id`,`purpose`);

--
-- Chỉ mục cho bảng `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`);

--
-- AUTO_INCREMENT cho các bảng đã đổ
--

--
-- AUTO_INCREMENT cho bảng `tblotp`
--
ALTER TABLE `tblotp`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT cho bảng `users`
--
ALTER TABLE `users`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- Các ràng buộc cho các bảng đã đổ
--

--
-- Các ràng buộc cho bảng `notes`
--
ALTER TABLE `notes`
  ADD CONSTRAINT `notes_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Các ràng buộc cho bảng `tblotp`
--
ALTER TABLE `tblotp`
  ADD CONSTRAINT `tblotp_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
