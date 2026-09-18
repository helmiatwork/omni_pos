export function formatMoney(cents) {
  if (cents === null || cents === undefined) return 'Rp 0'
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0
  }).format(cents)
}

export function formatDate(isoDate) {
  if (!isoDate) return '-'
  const date = new Date(isoDate)
  return new Intl.DateTimeFormat('id-ID', {
    dateStyle: 'medium',
    timeStyle: 'short'
  }).format(date)
}

export function generateIdempotencyKey() {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID()
  }
  return 'idem-' + Math.random().toString(36).substring(2, 15) + Date.now().toString(36)
}
