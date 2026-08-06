'use strict';

const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const router = express.Router();

const env = require('../../config/env');
const { authenticate } = require('../../middleware/auth');
const ApiError = require('../../utils/ApiError');

const uploadDir = path.resolve(env.uploads.tempDir);
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const ALLOWED_MIME_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp', 'application/pdf']);

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const uniqueName = `${Date.now()}-${crypto.randomBytes(8).toString('hex')}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: env.uploads.maxSizeMb * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (!ALLOWED_MIME_TYPES.has(file.mimetype)) {
      return cb(ApiError.badRequest('Only JPEG, PNG, WEBP images or PDF files are allowed'));
    }
    cb(null, true);
  },
});

/**
 * @openapi
 * /uploads:
 *   post:
 *     summary: Upload a file (delivery proof photo, driver document, profile photo)
 *     tags: [Uploads]
 *     security: [{ bearerAuth: [] }]
 *     requestBody:
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               file:
 *                 type: string
 *                 format: binary
 */
router.post('/', authenticate, upload.single('file'), (req, res) => {
  if (!req.file) throw ApiError.badRequest('No file was uploaded (expected field name "file")');
  const fileUrl = `${env.apiBaseUrl}/uploads/${req.file.filename}`;
  res.status(201).json({
    success: true,
    data: { url: fileUrl, filename: req.file.filename, sizeBytes: req.file.size },
  });
});

module.exports = { router, uploadDir };
