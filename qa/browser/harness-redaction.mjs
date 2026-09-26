export function redact(value, limit = 8000) {
  return String(value).replace(/Bearer\s+\S+/gi, 'Bearer [redacted]')
    .replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, '[jwt-redacted]')
    .replace(/((?:token|apikey|password|cookie|authorization)["'\s:=]+)[^\s,;]+/gi, '$1[redacted]')
    .replace(/(https?:\/\/[^\s?#]+)[?#][^\s]*/g, '$1[parameters-redacted]')
    .slice(0, limit);
}
