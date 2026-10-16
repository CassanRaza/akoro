export const toIsoDateTime = (value) => {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? value : date.toISOString();
};

export const toDateTimeLocal = (value) => {
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  const pad = (part) => String(part).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
};

export const calculateQcmDeadline = (dateDebut, dureeMinutes) => {
  if (!dateDebut) return null;
  const deadline = new Date(dateDebut);
  const duration = Number(dureeMinutes);
  if (Number.isNaN(deadline.getTime()) || !Number.isFinite(duration) || duration <= 0) {
    return null;
  }

  deadline.setTime(deadline.getTime() + duration * 60_000);
  return deadline.toISOString();
};
