'use strict';

const { S3Client, GetObjectCommand, PutObjectCommand } = require('@aws-sdk/client-s3');
const sharp = require('sharp');

const s3   = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });
const SIZE = 40;
const CIRCLE_MASK = Buffer.from(
  `<svg viewBox="0 0 ${SIZE} ${SIZE}" xmlns="http://www.w3.org/2000/svg">` +
  `<circle cx="${SIZE / 2}" cy="${SIZE / 2}" r="${SIZE / 2}"/></svg>`
);

exports.handler = async (event) => {
  const batchItemFailures = [];

  for (const record of event.Records) {
    try {
      await processRecord(record);
    } catch (err) {
      console.error(`Error procesando mensaje ${record.messageId}:`, err);
      batchItemFailures.push({ itemIdentifier: record.messageId });
    }
  }

  console.log(`Batch: ${event.Records.length} mensajes, ${batchItemFailures.length} fallos`);
  return { batchItemFailures };
};

async function processRecord(record) {
  const body = JSON.parse(record.body);
  if (!body.Records?.length) { console.log('Notificación de prueba S3 — ignorada'); return; }

  for (const s3Record of body.Records) {
    if (!s3Record.eventName?.startsWith('ObjectCreated')) continue;

    const srcKey = decodeURIComponent(s3Record.s3.object.key.replace(/\+/g, ' '));
    const uploadBucket    = process.env.UPLOAD_BUCKET;
    const processedBucket = process.env.PROCESSED_BUCKET;

    console.log(`Procesando: s3://${uploadBucket}/${srcKey}`);

    // Descargar imagen original
    const { Body } = await s3.send(new GetObjectCommand({ Bucket: uploadBucket, Key: srcKey }));
    const inputBuffer = await streamToBuffer(Body);

    // Recortar a 40x40 con máscara circular
    const circularPng = await sharp(inputBuffer)
      .resize(SIZE, SIZE, { fit: 'cover', position: 'centre' })
      .composite([{ input: CIRCLE_MASK, blend: 'dest-in' }])
      .png({ compressionLevel: 9 })
      .toBuffer();

    // Nombre de salida: <basename>_circular.png
    const baseName = srcKey.split('/').pop().replace(/\.[^.]+$/, '');
    const destKey  = `${baseName}_circular.png`;

    await s3.send(new PutObjectCommand({
      Bucket:               processedBucket,
      Key:                  destKey,
      Body:                 circularPng,
      ContentType:          'image/png',
      ServerSideEncryption: 'AES256',
    }));

    console.log(`Guardado: s3://${processedBucket}/${destKey} (${circularPng.length} bytes)`);
  }
}

async function streamToBuffer(stream) {
  const chunks = [];
  for await (const chunk of stream) chunks.push(chunk);
  return Buffer.concat(chunks);
}
