String fDateCourte(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String fHeure(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}