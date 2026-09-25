export default function SupporterEmblem({ className = '' }: { className?: string }) {
  return <span className={`supporter-emblem ${className}`} role="img" aria-label="Emblema de apoiador">
    <svg viewBox="0 0 64 64" fill="none" aria-hidden="true">
      <path className="supporter-emblem-glow" d="M8 21 21 30 32 8l11 22 13-9-5 28H13z"/>
      <path className="supporter-emblem-outline" d="M8 21 21 30 32 8l11 22 13-9-5 28H13z"/>
      <path className="supporter-emblem-inner" d="m19 39 8 3 5-12 5 12 8-3"/>
      <path className="supporter-emblem-outline" d="M15 55h34"/>
      <path className="supporter-emblem-crown" d="m32 14 3 7-3 7-3-7z"/>
    </svg>
  </span>;
}
