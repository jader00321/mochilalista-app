import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/auth_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../providers/team_provider.dart';
import '../widgets/team/team_members_tab.dart';
import '../widgets/team/access_codes_tab.dart';
class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  @override
  void initState() {
    super.initState();
    // Cargamos los datos al abrir la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.activeBusinessId != null) {
        final teamProv = Provider.of<TeamProvider>(context, listen: false);
        teamProv.fetchTeam(auth.activeBusinessId!);
        teamProv.fetchAccessCodes(auth.activeBusinessId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = Provider.of<ThemeProvider>(context);
    final isDark = themeProv.isDarkMode;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF14141C) : Colors.blue[800],
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text("Mi Equipo y Accesos", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.orangeAccent,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.people), text: "Miembros"),
              Tab(icon: Icon(Icons.vpn_key), text: "Códigos de Invitación"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TeamMembersTab(),
            AccessCodesTab(),
          ],
        ),
      ),
    );
  }
}