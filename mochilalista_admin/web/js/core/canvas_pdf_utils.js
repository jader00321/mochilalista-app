// =================== HELPERS CANVAS 2D Y GENERADOR PDF OFFLINE ===================
function drawFallbackLogo(ctx, x, y, w, h, color) {
  ctx.fillStyle = color;
  roundRect(ctx, x, y, w, h, 12, true, false);
  ctx.fillStyle = '#ffffff';
  ctx.font = 'bold 36px sans-serif';
  ctx.textAlign = 'center';
  ctx.fillText('M', x + w / 2, y + h / 2 + 12);
}

function roundRect(ctx, x, y, w, h, r, fill, stroke) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
  if (fill) ctx.fill();
  if (stroke) ctx.stroke();
}

function wrapText(ctx, text, x, y, maxWidth, lineHeight) {
  if (!text) return;
  const words = text.split(' ');
  let line = '';
  for (let n = 0; n < words.length; n++) {
    const testLine = line + words[n] + ' ';
    const metrics = ctx.measureText(testLine);
    if (metrics.width > maxWidth && n > 0) {
      ctx.fillText(line, x, y);
      line = words[n] + ' ';
      y += lineHeight;
    } else {
      line = testLine;
    }
  }
  ctx.fillText(line, x, y);
}

function generateOfflinePdfFromCanvas(canvas, fileName) {
  const dataUrl = canvas.toDataURL('image/jpeg', 0.95);
  const base64Data = dataUrl.split(',')[1];
  const binaryImg = atob(base64Data);
  const imgLen = binaryImg.length;
  const imgBytes = new Uint8Array(imgLen);
  for (let i = 0; i < imgLen; i++) {
    imgBytes[i] = binaryImg.charCodeAt(i);
  }

  const pageWidth = 842; // A4 horizontal en puntos tipográficos (~841.89 pt)
  const pageHeight = 595; // A4 horizontal (~595.28 pt)
  const imgW = 760;
  const imgH = +(imgW * (canvas.height / canvas.width)).toFixed(2);
  const imgX = +((pageWidth - imgW) / 2).toFixed(2);
  const imgY = +((pageHeight - imgH) / 2).toFixed(2);

  const enc = new TextEncoder();
  const parts = [];
  const offsets = [];

  function addString(str) {
    const b = enc.encode(str);
    parts.push(b);
    return b.length;
  }

  function addBytes(bytes) {
    parts.push(bytes);
    return bytes.length;
  }

  let currentOffset = 0;
  function markObj(num) {
    offsets[num] = currentOffset;
  }

  // Encabezado PDF 1.4 binario estándar
  currentOffset += addString('%PDF-1.4\n%\xFF\xFF\xFF\xFF\n');

  // Objeto 1: Catalog
  markObj(1);
  currentOffset += addString('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');

  // Objeto 2: Pages
  markObj(2);
  currentOffset += addString('2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n');

  // Objeto 3: Page
  markObj(3);
  currentOffset += addString(
    `3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${pageWidth} ${pageHeight}] ` +
    `/Resources << /XObject << /Im1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n`
  );

  // Objeto 4: Image XObject (JPEG /DCTDecode)
  markObj(4);
  currentOffset += addString(
    `4 0 obj\n<< /Type /XObject /Subtype /Image /Width ${canvas.width} /Height ${canvas.height} ` +
    `/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${imgLen} >>\nstream\n`
  );
  currentOffset += addBytes(imgBytes);
  currentOffset += addString('\nendstream\nendobj\n');

  // Objeto 5: Page Content stream
  const contentStream = `q\n${imgW} 0 0 ${imgH} ${imgX} ${imgY} cm\n/Im1 Do\nQ\n`;
  const contentLen = enc.encode(contentStream).length;
  markObj(5);
  currentOffset += addString(`5 0 obj\n<< /Length ${contentLen} >>\nstream\n${contentStream}endstream\nendobj\n`);

  // Tabla Xref
  const xrefStart = currentOffset;
  let xrefStr = 'xref\n0 6\n0000000000 65535 f \n';
  for (let i = 1; i <= 5; i++) {
    const offStr = String(offsets[i]).padStart(10, '0');
    xrefStr += `${offStr} 00000 n \n`;
  }
  xrefStr += `trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n${xrefStart}\n%%EOF\n`;
  addString(xrefStr);

  // Consolidar buffer binario completo
  const totalLength = parts.reduce((acc, p) => acc + p.length, 0);
  const pdfBytes = new Uint8Array(totalLength);
  let pos = 0;
  for (const p of parts) {
    pdfBytes.set(p, pos);
    pos += p.length;
  }

  const blob = new Blob([pdfBytes], { type: 'application/pdf' });
  const link = document.createElement('a');
  link.href = URL.createObjectURL(blob);
  link.download = fileName;
  link.click();
  setTimeout(() => URL.revokeObjectURL(link.href), 10000);
}

function sanitizeDownloadFileName(str) {
  return String(str || '').replace(/[\/\\:*?"<>|]/g, '_').replace(/\s+/g, '_');
}
