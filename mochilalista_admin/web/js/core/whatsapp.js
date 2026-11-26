// =================== CONSTRUCTOR CANÓNICO DE ENLACES WHATSAPP (DRY D-ADM-06) ===================
function sanitizeWhatsAppDigits(phone) {
  let digits = String(phone || '').replace(/\D/g, '');
  if (digits.length === 9 && digits.startsWith('9')) {
    digits = '51' + digits;
  }
  return digits;
}

function buildWhatsAppSendUrl(phone, text = '') {
  const digits = sanitizeWhatsAppDigits(phone);
  const hasText = text !== null && text !== undefined && String(text).length > 0;
  const encodedText = hasText ? encodeURIComponent(String(text)) : '';
  if (digits && encodedText) {
    return `https://api.whatsapp.com/send?phone=${digits}&text=${encodedText}`;
  }
  if (digits) {
    return `https://api.whatsapp.com/send?phone=${digits}`;
  }
  if (encodedText) {
    return `https://api.whatsapp.com/send?text=${encodedText}`;
  }
  return 'https://api.whatsapp.com/send';
}
