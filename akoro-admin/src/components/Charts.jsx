import { useLayoutEffect, useRef, useState } from 'react';
import './Charts.css';

// Graphiques légers en SVG/HTML, une seule série chacun (couleur = var(--teal)).
// Le survol affiche une infobulle ; les valeurs restent lisibles sans couleur.

const jourCourt = (iso) =>
  new Date(`${iso}T00:00:00`).toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' });
const jourLong = (iso) =>
  new Date(`${iso}T00:00:00`).toLocaleDateString('fr-FR', { weekday: 'short', day: 'numeric', month: 'short' });

function useWidth() {
  const ref = useRef(null);
  const [width, setWidth] = useState(0);

  useLayoutEffect(() => {
    if (!ref.current) return undefined;
    const obs = new ResizeObserver(([entry]) => setWidth(entry.contentRect.width));
    obs.observe(ref.current);
    return () => obs.disconnect();
  }, []);

  return [ref, width];
}

function Tooltip({ x, y, width, children }) {
  // Reste dans les limites du graphique
  const left = Math.min(Math.max(x, 70), Math.max(width - 70, 70));
  return (
    <div className="chart-tooltip" style={{ left, top: y }} role="status">
      {children}
    </div>
  );
}

/** Barres horizontales : [{ id, label, value, detail }] */
export function HBarChart({ items, unit = '', emptyText = 'Aucune donnée' }) {
  const [hover, setHover] = useState(null);
  const max = Math.max(1, ...items.map((i) => i.value));

  if (items.length === 0) return <p className="chart-empty">{emptyText}</p>;

  return (
    <ul className="hbar">
      {items.map((item) => (
        <li
          key={item.id}
          className={`hbar-row${hover === item.id ? ' is-hover' : ''}`}
          onMouseEnter={() => setHover(item.id)}
          onMouseLeave={() => setHover(null)}
        >
          <span className="hbar-label" title={item.label}>{item.label}</span>
          <span className="hbar-track">
            <span
              className="hbar-fill"
              style={{ width: `${(item.value / max) * 100}%` }}
            />
          </span>
          <span className="hbar-value">{item.value}{unit}</span>
          {hover === item.id && item.detail && <span className="hbar-tip">{item.detail}</span>}
        </li>
      ))}
    </ul>
  );
}

const PAD = { top: 12, right: 12, bottom: 26, left: 36 };

/** Courbe 0–100 % : points = [{ date, taux|null, presents, attendus }] — les jours sans séance coupent la ligne */
export function LineChart({ points, height = 200 }) {
  const [ref, width] = useWidth();
  const [hover, setHover] = useState(null);
  const avecDonnees = points.filter((p) => p.taux !== null);

  const w = Math.max(width, 200);
  const innerW = w - PAD.left - PAD.right;
  const innerH = height - PAD.top - PAD.bottom;
  const step = points.length > 1 ? innerW / (points.length - 1) : 0;
  const x = (i) => PAD.left + i * step;
  const y = (v) => PAD.top + innerH - (v / 100) * innerH;

  // Segments continus (jours consécutifs avec données)
  const segments = [];
  let courant = [];
  points.forEach((p, i) => {
    if (p.taux === null) {
      if (courant.length) segments.push(courant);
      courant = [];
    } else courant.push([x(i), y(p.taux)]);
  });
  if (courant.length) segments.push(courant);

  const labelEvery = Math.ceil(points.length / 7);
  const h = hover !== null ? points[hover] : null;

  return (
    <div className="chart" ref={ref}>
      {avecDonnees.length === 0 && (
        <p className="chart-overlay-empty">Aucune séance terminée sur la période</p>
      )}
      {width > 0 && (
        <svg width={w} height={height} role="img" aria-label="Taux de présence par jour">
          {[0, 50, 100].map((v) => (
            <g key={v}>
              <line className="chart-grid" x1={PAD.left} x2={w - PAD.right} y1={y(v)} y2={y(v)} />
              <text className="chart-axis" x={PAD.left - 8} y={y(v) + 4} textAnchor="end">{v} %</text>
            </g>
          ))}
          {points.map((p, i) =>
            i % labelEvery === 0 ? (
              <text key={p.date} className="chart-axis" x={x(i)} y={height - 6} textAnchor="middle">
                {jourCourt(p.date)}
              </text>
            ) : null
          )}
          {h && <line className="chart-crosshair" x1={x(hover)} x2={x(hover)} y1={PAD.top} y2={PAD.top + innerH} />}
          {segments.map((seg, i) =>
            seg.length > 1 ? (
              <polyline key={i} className="chart-line" points={seg.map((pt) => pt.join(',')).join(' ')} />
            ) : null
          )}
          {points.map((p, i) =>
            p.taux !== null ? (
              <circle key={p.date} className="chart-dot" cx={x(i)} cy={y(p.taux)} r={hover === i ? 5 : 4} />
            ) : null
          )}
          {/* Zones de survol plus larges que les marques */}
          {points.map((p, i) => (
            <rect
              key={p.date}
              x={x(i) - Math.max(step, 12) / 2}
              y={PAD.top}
              width={Math.max(step, 12)}
              height={innerH}
              fill="transparent"
              onMouseEnter={() => setHover(i)}
              onMouseLeave={() => setHover(null)}
            />
          ))}
        </svg>
      )}
      {h && (
        <Tooltip x={x(hover)} y={h.taux !== null ? y(h.taux) - 10 : PAD.top} width={w}>
          <strong>{jourLong(h.date)}</strong>
          {h.taux !== null ? (
            <span>{h.taux} % · {h.presents}/{h.attendus} présents</span>
          ) : (
            <span>Pas de séance</span>
          )}
        </Tooltip>
      )}
    </div>
  );
}

/** Colonnes par jour : points = [{ date, total }] */
export function ColumnChart({ points, height = 160, unitLabel = 'messages' }) {
  const [ref, width] = useWidth();
  const [hover, setHover] = useState(null);

  const w = Math.max(width, 200);
  const innerW = w - PAD.left - PAD.right;
  const innerH = height - PAD.top - PAD.bottom;
  const max = Math.max(1, ...points.map((p) => p.total));
  const slot = innerW / Math.max(points.length, 1);
  const barW = Math.max(2, Math.min(28, slot - 2)); // 2px d'espace entre les barres
  const x = (i) => PAD.left + i * slot + (slot - barW) / 2;
  const y = (v) => PAD.top + innerH - (v / max) * innerH;
  const labelEvery = Math.ceil(points.length / 7);
  const h = hover !== null ? points[hover] : null;

  return (
    <div className="chart" ref={ref}>
      {width > 0 && (
        <svg width={w} height={height} role="img" aria-label="Messages par jour">
          {[0, max].map((v) => (
            <g key={v}>
              <line className="chart-grid" x1={PAD.left} x2={w - PAD.right} y1={y(v)} y2={y(v)} />
              <text className="chart-axis" x={PAD.left - 8} y={y(v) + 4} textAnchor="end">{v}</text>
            </g>
          ))}
          {points.map((p, i) => {
            const top = y(p.total);
            const hBar = PAD.top + innerH - top;
            const r = Math.min(4, barW / 2, hBar);
            // Coins arrondis uniquement en haut, ancrés sur la ligne de base
            const d = hBar > 0
              ? `M${x(i)},${PAD.top + innerH} V${top + r} Q${x(i)},${top} ${x(i) + r},${top} H${x(i) + barW - r} Q${x(i) + barW},${top} ${x(i) + barW},${top + r} V${PAD.top + innerH} Z`
              : null;
            return (
              <g key={p.date}>
                {d && <path className={`chart-bar${hover === i ? ' is-hover' : ''}`} d={d} />}
                {i % labelEvery === 0 && (
                  <text className="chart-axis" x={x(i) + barW / 2} y={height - 6} textAnchor="middle">
                    {jourCourt(p.date)}
                  </text>
                )}
                <rect
                  x={PAD.left + i * slot}
                  y={PAD.top}
                  width={slot}
                  height={innerH}
                  fill="transparent"
                  onMouseEnter={() => setHover(i)}
                  onMouseLeave={() => setHover(null)}
                />
              </g>
            );
          })}
        </svg>
      )}
      {h && (
        <Tooltip x={x(hover) + barW / 2} y={y(h.total) - 10} width={w}>
          <strong>{jourLong(h.date)}</strong>
          <span>{h.total} {unitLabel}</span>
        </Tooltip>
      )}
    </div>
  );
}
