import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../../../models/planning.dart';
import '../../../core/services/planning_database.dart';
import '../widgets/planning_card.dart';
import 'edit_planning_page.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<Planning> _plannings = [];

  @override
  void initState() {
    super.initState();
    _loadPlannings();
  }

  _loadPlannings() async {
    final data = await PlanningDatabase.instance.readAllPlannings();
    setState(() => _plannings = data);
  }

  // Filtre approximatif : match le jour du mois
  List<Planning> _getPlanningsForDay(DateTime day) {
    final dayStr = DateFormat('d', 'fr_FR').format(day);
    return _plannings.where((p) => p.date.contains(dayStr)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final planningsDuJour = _getPlanningsForDay(_selectedDay);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Semaine du ${DateFormat('d MMM', 'fr_FR').format(_focusedDay)}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ),
          Container(
            color: Colors.white,
            child: TableCalendar(
              locale: 'fr_FR',
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: CalendarFormat.week,
              headerVisible: false,
              daysOfWeekHeight: 20,
              rowHeight: 65,
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                todayDecoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(12),
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(12),
                ),
                defaultDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                markerDecoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormat('EEEE d MMM', 'fr_FR').format(_selectedDay),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: planningsDuJour.isEmpty
                ? const Center(
              child: Text('Aucun trajet ce jour',
                  style: TextStyle(color: Colors.grey)),
            )
                : ListView.builder(
              itemCount: planningsDuJour.length,
              itemBuilder: (context, index) {
                final p = planningsDuJour[index];
                return PlanningCard(
                  planning: p,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditPlanningPage(planning: p),
                      ),
                    );
                    _loadPlannings();
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, color: Colors.blue),
                label: const Text(
                  'Planifier un trajet récurrent',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.blue.shade100),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  backgroundColor: Colors.blue.shade50.withOpacity(0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}