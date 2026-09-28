import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_provider.dart';
import '../../core/constants/app_colors.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  String _query = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadAdminData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==============================================================
  // DATE FORMATTING
  //
  // Handles both ISO-8601 strings and epoch milliseconds, since
  // ServerValue.timestamp writes an int to Realtime Database.
  // ==============================================================

  String _formatDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return "Not available";
    }

    DateTime? date;

    if (value is int) {
      date = DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    } else if (value is num) {
      date = DateTime.fromMillisecondsSinceEpoch(value.toInt())
          .toLocal();
    } else {
      final text = value.toString();

      // Numeric string, e.g. "1758000000000"
      final asMillis = int.tryParse(text);

      if (asMillis != null && text.length >= 10) {
        date = DateTime.fromMillisecondsSinceEpoch(
          text.length <= 10 ? asMillis * 1000 : asMillis,
        ).toLocal();
      } else {
        date = DateTime.tryParse(text)?.toLocal();
      }
    }

    if (date == null) {
      return value.toString();
    }

    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final period = date.hour < 12 ? 'AM' : 'PM';

    return "${date.month.toString().padLeft(2, '0')}/"
        "${date.day.toString().padLeft(2, '0')}/"
        "${date.year} "
        "${hour12.toString().padLeft(2, '0')}:"
        "${date.minute.toString().padLeft(2, '0')} $period";
  }

  /// Reads the first key that actually exists, so the screen works
  /// whether the node stores registeredAt or createdAt.
  dynamic _firstOf(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Registered Users",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<AdminProvider>(
        builder: (context, admin, _) {
          if (admin.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (admin.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 50,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      admin.error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        admin.clearError();
                        admin.loadAdminData();
                      },
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              ),
            );
          }

          if (admin.users.isEmpty) {
            return RefreshIndicator(
              onRefresh: admin.loadAdminData,
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(
                    Icons.people_outline,
                    size: 56,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      "No registered users found.",
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // ------------------------------------------------------
          // NORMALIZE + SORT (admins first, then alphabetical)
          // ------------------------------------------------------

          final all = admin.users.entries.map((entry) {
            final data = entry.value is Map
                ? Map<String, dynamic>.from(entry.value as Map)
                : <String, dynamic>{};

            return _UserRow(
              uid: entry.key.toString(),
              name: data['name']?.toString().trim().isNotEmpty == true
                  ? data['name'].toString()
                  : "SmartDrip User",
              email: data['email']?.toString() ?? "No email",
              role: (data['role']?.toString() ?? "user").toLowerCase(),
              registeredAt: _firstOf(
                data,
                ['registeredAt', 'createdAt', 'created_at'],
              ),
              lastLogin: _firstOf(
                data,
                ['lastLogin', 'last_login', 'lastLoginAt'],
              ),
            );
          }).toList();

          all.sort((a, b) {
            if (a.isAdmin != b.isAdmin) {
              return a.isAdmin ? -1 : 1;
            }
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

          final users = _query.isEmpty
              ? all
              : all.where((u) {
                  final q = _query.toLowerCase();
                  return u.name.toLowerCase().contains(q) ||
                      u.email.toLowerCase().contains(q) ||
                      u.role.contains(q);
                }).toList();

          final adminCount = all.where((u) => u.isAdmin).length;

          return RefreshIndicator(
            onRefresh: admin.loadAdminData,
            child: Column(
              children: [
                // --------------------------------------------
                // HEADER + SEARCH
                // --------------------------------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${all.length} total "
                        "\u2022 $adminCount admin "
                        "\u2022 ${all.length - adminCount} user",
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() => _query = value.trim());
                        },
                        decoration: InputDecoration(
                          hintText: "Search name, email, or role",
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // --------------------------------------------
                // LIST
                // --------------------------------------------
                Expanded(
                  child: users.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 60),
                            Center(
                              child: Text(
                                "No users match your search.",
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            return _buildUserCard(users[index]);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserCard(_UserRow user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withOpacity(.10),
                  child: Icon(
                    user.isAdmin
                        ? Icons.admin_panel_settings
                        : Icons.person,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: user.isAdmin
                        ? AppColors.primary.withOpacity(.12)
                        : Colors.grey.withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.role.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: user.isAdmin
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Divider(),

            const SizedBox(height: 8),

            _infoRow(
              Icons.calendar_today_outlined,
              "Registration Date",
              _formatDate(user.registeredAt),
            ),

            const SizedBox(height: 10),

            _infoRow(
              Icons.login,
              "Last Login",
              _formatDate(user.lastLogin),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ================================================================
// SIMPLE VIEW MODEL FOR ONE ROW
// ================================================================

class _UserRow {
  final String uid;
  final String name;
  final String email;
  final String role;
  final dynamic registeredAt;
  final dynamic lastLogin;

  const _UserRow({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.registeredAt,
    required this.lastLogin,
  });

  bool get isAdmin => role == "admin";
}