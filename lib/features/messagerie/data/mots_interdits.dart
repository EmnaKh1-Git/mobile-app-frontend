// ============================================================
// MOTS INTERDITS (filtre anti-abus)
// Liste courte à compléter librement : un mot ou une expression
// par entrée. La comparaison se fait sur le texte normalisé
// (minuscules, sans accents) et en mots entiers.
// ============================================================

const List<String> motsInterdits = [
  // --- Français ---
  'merde',
  'connard',
  'salaud',
  'abruti',
  'idiot',
  'con',
  'imbécile',
  'ordure',
  'crétin',
  'ferme ta gueule',

  // --- Anglais ---
  'fuck',
  'shit',
  'bastard',
  'idiot',

  // --- Dialecte tunisien (lettres latines) ---
  'kelb',
  'zebbi',
  'zebi',
  'kahba',
  'tnes',
  'njibek',
  'zabour',
];
