import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import 'widgets/user_avatar_view.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _userService = UserService.instance;
  List<UserModel> _allUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'Tous';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await _userService.getAllUsersForAdmin();
    if (mounted) {
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
    }
  }

  List<UserModel> get _filteredUsers {
    return _allUsers.where((u) {
      final isSelfAdmin = u.email.toLowerCase() == 'admin@esprit.tn';
      if (isSelfAdmin) return false;

      if (_selectedFilter == 'Conducteurs' && !u.isConducteur) return false;
      if (_selectedFilter == 'Passagers' && !u.isPassager) return false;
      if (_selectedFilter == 'Bannis' && !u.isBanni) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = u.nomComplet.toLowerCase().contains(q);
        final matchEmail = u.email.toLowerCase().contains(q);
        final matchPhone = u.telephone.contains(q);
        final matchUniv = u.universite.toLowerCase().contains(q);
        if (!matchName && !matchEmail && !matchPhone && !matchUniv) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _handleBanUser(UserModel user) async {
    final reasonCtrl = TextEditingController(text: 'Non-respect de la charte de covoiturage.');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.block_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text('Suspendre ${user.prenom} ?', style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'L\'utilisateur "${user.email}" ne pourra plus se connecter à son compte.',
              style: const TextStyle(fontSize: 13, color: AppColors.texte2),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Motif du bannissement',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Bannir le compte'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _userService.banUser(user.email, reason: reasonCtrl.text.trim());
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Compte ${user.email} banni avec succès.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _handleUnbanUser(UserModel user) async {
    await _userService.unbanUser(user.email);
    await _loadUsers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Compte ${user.email} réactivé et débloqué !'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  Future<void> _handleDeleteUser(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Supprimer définitivement ?', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer définitivement le compte de ${user.nomComplet} (${user.email}) ? Cette action est irréversible.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _userService.deleteUserByAdmin(user.email);
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Compte ${user.email} supprimé.'),
          backgroundColor: Colors.grey[800],
        ),
      );
    }
  }

  Future<void> _handleToggleRole(UserModel user) async {
    if (user.isAdmin || user.email.toLowerCase() == 'admin@esprit.tn') {
      return;
    }
    final newRole = user.isConducteur ? UserRole.passager : UserRole.conducteur;
    await _userService.changeUserRoleByAdmin(user.email, newRole);
    await _loadUsers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rôle de ${user.prenom} changé en "${newRole.label}".'),
        backgroundColor: AppColors.primaire,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalUsers = _allUsers.where((u) => u.email != 'admin@esprit.tn').length;
    final totalDrivers = _allUsers.where((u) => u.isConducteur && u.email != 'admin@esprit.tn').length;
    final totalPassengers = _allUsers.where((u) => u.isPassager && u.email != 'admin@esprit.tn').length;
    final totalBanned = _allUsers.where((u) => u.isBanni && u.email != 'admin@esprit.tn').length;

    final filtered = _filteredUsers;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Espace Administration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'Modération des comptes utilisateurs',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1B4B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Actualiser la liste',
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUsers,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _buildStatBox('Total', '$totalUsers', Icons.people_alt_rounded, const Color(0xFF4F46E5)),
                        const SizedBox(width: 8),
                        _buildStatBox('Conducteurs', '$totalDrivers', Icons.directions_car, AppColors.accent),
                        const SizedBox(width: 8),
                        _buildStatBox('Passagers', '$totalPassengers', Icons.person_pin_circle, AppColors.primaire),
                        const SizedBox(width: 8),
                        _buildStatBox('Bannis', '$totalBanned', Icons.block_rounded, Colors.redAccent),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildDynamicRoleDistributionCard(
                      totalDrivers: totalDrivers,
                      totalPassengers: totalPassengers,
                      totalUsers: totalUsers,
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Rechercher par nom, email, téléphone...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.texte2),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.bordure),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.bordure),
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    ),
                    const SizedBox(height: 12),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Tous'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Conducteurs'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Passagers'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Bannis'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Comptes enregistrés (${filtered.length})',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                        ),
                        Text(
                          'Base SQLite active',
                          style: TextStyle(fontSize: 11, color: Colors.green[700], fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (filtered.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(Icons.person_search_rounded, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            const Text(
                              'Aucun utilisateur ne correspond à ce critère.',
                              style: TextStyle(color: AppColors.texte2, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (ctx, idx) {
                          final user = filtered[idx];
                          return _buildUserCard(user);
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatBox(String title, String count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.bordure),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              count,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 10, color: AppColors.texte2),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = label),
      selectedColor: const Color(0xFF1E1B4B),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF374151),
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? Colors.transparent : AppColors.bordure),
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    final isBanned = user.isBanni;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBanned ? Colors.redAccent.withValues(alpha: 0.4) : AppColors.bordure,
          width: isBanned ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatarView(user: user, radius: 24),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.nomComplet,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isBanned ? Colors.grey[700] : const Color(0xFF1F2937),
                              decoration: isBanned ? TextDecoration.lineThrough : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: user.isConducteur ? AppColors.accentDoux : AppColors.primaireDoux,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user.role.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: user.isConducteur ? AppColors.accent : AppColors.primaire,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: const TextStyle(fontSize: 12, color: AppColors.texte2),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isBanned ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBanned ? Icons.block : Icons.check_circle,
                      size: 12,
                      color: isBanned ? Colors.red[700] : const Color(0xFF047857),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isBanned ? 'Banni' : 'Actif',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isBanned ? Colors.red[700] : const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.bordure),
          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(Icons.school_outlined, size: 14, color: AppColors.texte2),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${user.universite} (${user.gouvernorat})',
                  style: const TextStyle(fontSize: 11, color: AppColors.texte2),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.phone_outlined, size: 14, color: AppColors.texte2),
              const SizedBox(width: 4),
              Text(
                user.telephoneComplet,
                style: const TextStyle(fontSize: 11, color: AppColors.texte2),
              ),
            ],
          ),

          if (user.isConducteur && user.marqueVehicule != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.directions_car_outlined, size: 14, color: AppColors.accent),
                const SizedBox(width: 4),
                Text(
                  '${user.marqueVehicule} ${user.modeleVehicule ?? ""} (${user.couleurVehicule ?? ""}) - ${user.immatriculation ?? "N/A"}',
                  style: const TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],

          if (isBanned && user.raisonBlocage != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                'Motif : ${user.raisonBlocage}',
                style: const TextStyle(fontSize: 11, color: Colors.redAccent),
              ),
            ),
          ],

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _handleToggleRole(user),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: Text(
                  user.isConducteur ? 'Rendre Passager' : 'Rendre Conducteur',
                  style: const TextStyle(fontSize: 11),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 6),

              if (isBanned)
                ElevatedButton.icon(
                  onPressed: () => _handleUnbanUser(user),
                  icon: const Icon(Icons.check_circle_outline, size: 14),
                  label: const Text('Débloquer', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _handleBanUser(user),
                  icon: const Icon(Icons.block, size: 14, color: Colors.redAccent),
                  label: const Text('Bannir', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              const SizedBox(width: 6),

              IconButton(
                onPressed: () => _handleDeleteUser(user),
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                tooltip: 'Supprimer définitivement',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicRoleDistributionCard({
    required int totalDrivers,
    required int totalPassengers,
    required int totalUsers,
  }) {
    final totalActive = totalDrivers + totalPassengers;
    final double driverPct = totalActive > 0 ? (totalDrivers / totalActive) * 100 : 0.0;
    final double passengerPct = totalActive > 0 ? (totalPassengers / totalActive) * 100 : 0.0;
    final String ratioText = totalDrivers > 0
        ? (totalPassengers / totalDrivers).toStringAsFixed(1)
        : totalPassengers.toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1E1B4B),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.pie_chart_rounded, color: Color(0xFF4F46E5), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Répartition Passagers vs Conducteurs',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalActive membres actifs',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4338CA),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tranche visuelle proportionnelle représentant l\'équilibre entre offreurs de places et demandeurs de trajets.',
            style: TextStyle(fontSize: 11, color: AppColors.texte2),
          ),
          const SizedBox(height: 14),

          if (totalActive == 0)
            Container(
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Text(
                'Aucun membre enregistré dans la base',
                style: TextStyle(fontSize: 11, color: AppColors.texte2),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: SizedBox(
                height: 34,
                child: Row(
                  children: [
                    if (totalDrivers > 0)
                      Expanded(
                        flex: (driverPct * 10).round().clamp(1, 1000),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFF8A00), Color(0xFFFF5252)],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.directions_car, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                '${driverPct.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (totalPassengers > 0)
                      Expanded(
                        flex: (passengerPct * 10).round().clamp(1, 1000),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_pin_circle, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                '${passengerPct.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedFilter = 'Conducteurs'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFEDD5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF7A00),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Flexible(
                              child: Text(
                                'Conducteurs',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFFC2410C),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalDrivers (${driverPct.toStringAsFixed(1)}%)',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF9A3412),
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          '🚗 Offre : Propriétaires de voitures partageant leurs places pour amortir l\'essence.',
                          style: TextStyle(fontSize: 10, color: Color(0xFF7C2D12), height: 1.25),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedFilter = 'Passagers'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFF3B82F6),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Flexible(
                              child: Text(
                                'Passagers',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF1D4ED8),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalPassengers (${passengerPct.toStringAsFixed(1)}%)',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          '📍 Demande : Étudiants sans véhicule réservant des trajets vers les facultés.',
                          style: TextStyle(fontSize: 10, color: Color(0xFF1E3A8A), height: 1.25),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          _buildNetworkEquilibriumBanner(
            totalDrivers: totalDrivers,
            totalPassengers: totalPassengers,
            driverPct: driverPct,
            ratioText: ratioText,
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkEquilibriumBanner({
    required int totalDrivers,
    required int totalPassengers,
    required double driverPct,
    required String ratioText,
  }) {
    Color bg;
    Color border;
    Color textCol;
    IconData icon;
    String title;
    String description;

    if (totalDrivers == 0 && totalPassengers == 0) {
      bg = const Color(0xFFF3F4F6);
      border = const Color(0xFFE5E7EB);
      textCol = const Color(0xFF4B5563);
      icon = Icons.info_outline_rounded;
      title = 'Plateforme en phase de démarrage';
      description = 'Aucun membre enregistré dans la base.';
    } else if (totalDrivers == 0) {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFECACA);
      textCol = const Color(0xFFB91C1C);
      icon = Icons.warning_amber_rounded;
      title = 'Déficit d\'Offre (0 conducteur disponible)';
      description = 'Tous les membres sont des passagers. Aucun trajet ne peut débuter sans conducteurs avec véhicule.';
    } else if (driverPct < 25) {
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFDE68A);
      textCol = const Color(0xFFB45309);
      icon = Icons.trending_up_rounded;
      title = 'Forte Pression sur les Places (Ratio : 1 cond. pour $ratioText pass.)';
      description = 'La demande dépasse l\'offre de voitures. Priorité : inscription de conducteurs étudiants.';
    } else if (driverPct >= 25 && driverPct <= 55) {
      bg = const Color(0xFFECFDF5);
      border = const Color(0xFFA7F3D0);
      textCol = const Color(0xFF047857);
      icon = Icons.check_circle_outline_rounded;
      title = 'Écosystème Harmonieux & Équilibré (Ratio : 1 cond. pour $ratioText pass.)';
      description = 'La proportion entre véhicules et passagers offre une disponibilité fluide et d\'excellents temps d\'attente.';
    } else {
      bg = const Color(0xFFEEF2FF);
      border = const Color(0xFFC7D2FE);
      textCol = const Color(0xFF4338CA);
      icon = Icons.local_taxi_rounded;
      title = 'Forte Disponibilité de Places (${driverPct.toStringAsFixed(1)}% conducteurs)';
      description = 'Large volume de véhicules disponibles facilitant le covoiturage pour tous.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textCol, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textCol,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 10,
                    color: textCol.withValues(alpha: 0.9),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
