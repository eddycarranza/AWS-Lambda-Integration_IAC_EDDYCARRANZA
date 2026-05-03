'use strict';

const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const busboy = require('busboy');
const { v4: uuidv4 } = require('uuid');

const s3 = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });
const ALLOWED = new Set(['image/jpeg', 'image/png', 'image/gif', 'image/webp']);
const MAX_BYTES = 10 * 1024 * 1024;

exports.handler = async (event) => {
  console.log('upload-lambda:', event.requestContext?.http?.method, event.rawPath);
  try {
    const ct = (event.headers?.['content-type'] || event.headers?.['Content-Type'] || '').toLowerCase();
    let fileBuffer, fileName, mimeType;

    if (ct.includes('multipart/form-data')) {
      ({ fileBuffer, fileName, mimeType } = await parseMultipart(event));
    } else if (ct.includes('application/json')) {
      const body = JSON.parse(event.body || '{}');
      if (!body.image) return respond(400, { error: 'Falta el campo "image" (base64)' });
      fileBuffer = Buffer.from(body.image, 'base64');
      fileName   = body.filename || 'upload';
      mimeType   = (body.mimeType || 'image/jpeg').toLowerCase();
    } else {
      return respond(400, { error: 'Content-Type no soportado. Usa multipart/form-data o application/json' });
    }

    if (!ALLOWED.has(mimeType))
      return respond(400, { error: `Tipo no permitido: ${mimeType}. Permitidos: jpg, png, gif, webp` });
    if (fileBuffer.length > MAX_BYTES)
      return respond(400, { error: `Archivo muy grande (${fileBuffer.length} bytes). Máximo: 10 MB` });

    const fileId = uuidv4();
    const ext    = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/gif': 'gif', 'image/webp': 'webp' }[mimeType] || 'jpg';
    const key    = `${fileId}.${ext}`;

    await s3.send(new PutObjectCommand({
      Bucket:               process.env.UPLOAD_BUCKET,
      Key:                  key,
      Body:                 fileBuffer,
      ContentType:          mimeType,
      ServerSideEncryption: 'AES256',
      Metadata:             { originalName: encodeURIComponent(fileName), fileId },
    }));

    console.log('Subido a S3:', { bucket: process.env.UPLOAD_BUCKET, key, size: fileBuffer.length });
    return respond(200, { success: true, fileId, key, size: fileBuffer.length });

  } catch (err) {
    console.error('Error en upload-lambda:', err);
    return respond(500, { error: 'Error interno del servidor' });
  }
};

function respond(statusCode, body) {
  return { statusCode, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) };
}

function parseMultipart(event) {
  return new Promise((resolve, reject) => {
    const ct = event.headers?.['content-type'] || event.headers?.['Content-Type'];
    const bb = busboy({ headers: { 'content-type': ct }, limits: { files: 1, fileSize: MAX_BYTES + 1 } });
    let result = null;

    bb.on('file', (_field, file, info) => {
      const chunks = [];
      file.on('data', d => chunks.push(d));
      file.on('end', () => {
        result = { fileBuffer: Buffer.concat(chunks), fileName: info.filename || 'upload', mimeType: (info.mimeType || 'image/jpeg').toLowerCase() };
      });
    });

    bb.on('close', () => result ? resolve(result) : reject(new Error('No se encontró campo de archivo')));
    bb.on('error', reject);

    const body = event.isBase64Encoded ? Buffer.from(event.body, 'base64') : Buffer.from(event.body || '', 'utf8');
    bb.write(body);
    bb.end();
  });
}
