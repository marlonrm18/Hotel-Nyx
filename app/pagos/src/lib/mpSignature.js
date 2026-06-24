'use strict';

const crypto = require('crypto');

/**
 * Verifica la firma del webhook de Mercado Pago (header `x-signature`).
 *
 * MP envia `x-signature: ts=<unix>,v1=<hmac_sha256_hex>` y `x-request-id`.
 * El manifiesto a firmar (segun la doc de MP) es:
 *     id:<data.id>;request-id:<x-request-id>;ts:<ts>;
 * donde <data.id> es el query param `data.id` (en minusculas si es alfanumerico).
 * Se calcula HMAC-SHA256 con el `webhook_secret` (leido de Secrets Manager) y
 * se compara con `v1` en tiempo constante.
 *
 * Devuelve true SOLO si la firma es valida. Sin esto, no se confia en el body.
 */
function parseSignatureHeader(xSignature) {
  const parts = {};
  for (const segment of String(xSignature).split(',')) {
    const idx = segment.indexOf('=');
    if (idx === -1) continue;
    const key = segment.slice(0, idx).trim();
    const value = segment.slice(idx + 1).trim();
    if (key) parts[key] = value;
  }
  return parts;
}

function verifyWebhookSignature({ xSignature, xRequestId, dataId, secret }) {
  if (!xSignature || !secret || dataId == null) return false;

  const { ts, v1 } = parseSignatureHeader(xSignature);
  if (!ts || !v1) return false;

  // data.id en minusculas si es alfanumerico (requisito de MP).
  const id = String(dataId).toLowerCase();

  let manifest = `id:${id};`;
  if (xRequestId) manifest += `request-id:${xRequestId};`;
  manifest += `ts:${ts};`;

  const expected = crypto.createHmac('sha256', secret).update(manifest).digest('hex');

  const a = Buffer.from(expected, 'utf8');
  const b = Buffer.from(v1, 'utf8');
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

module.exports = { verifyWebhookSignature, parseSignatureHeader };
