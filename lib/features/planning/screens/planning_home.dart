import 'package:flutter/material.dart';
import 'planning_page.dart';
import 'agenda_page.dart';
import 'rappels_page.dart';

class PlanningHome extends StatelessWidget {
  const PlanningHome({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Planning',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: 'Planning'),
              Tab(text: 'Agenda'),
              Tab(text: 'Rappels'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PlanningPage(),
            AgendaPage(),
            RappelsPage(),
          ],
        ),
      ),
    );
  }
}