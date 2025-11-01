// lib/widgets/npc/npc_list_item.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'; // For network images
import 'package:trpg_frontend/models/npc.dart';
import 'package:trpg_frontend/models/enums/npc_type.dart'; // Import NpcType enum helper functions

/// Represents a single NPC item in a list.
class NpcListItem extends StatelessWidget {
  final Npc npc;
  final VoidCallback? onTap; // Callback when the item is tapped

  const NpcListItem({
    super.key,
    required this.npc,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine leading widget: image or placeholder
    Widget leadingWidget;
    if (npc.imageUrl != null && npc.imageUrl!.isNotEmpty) {
      leadingWidget = CircleAvatar(
        backgroundImage: CachedNetworkImageProvider(npc.imageUrl!),
        // Optional: Add error handling for image loading
        onBackgroundImageError: (exception, stackTrace) {
          debugPrint('Error loading NPC image: $exception');
        },
        child: npc.imageUrl == null || npc.imageUrl!.isEmpty
            ? const Icon(Icons.person) // Placeholder if image fails
            : null,
      );
    } else {
      // Placeholder icon based on NPC type (example)
      leadingWidget = CircleAvatar(
        child: Icon(
          npc.type == NpcType.MONSTER ? Icons.pest_control : Icons.person_outline,
          color: Colors.white,
        ),
        backgroundColor: npc.type == NpcType.MONSTER ? Colors.red.shade700 : Colors.blue.shade700,
      );
    }

    // Format NPC type for display
    final String npcTypeDisplay = npcTypeToString(npc.type); // Using helper function

    return Card( // Wrap ListTile in a Card for better visual separation
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        leading: leadingWidget,
        title: Text(
          npc.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text('Type: $npcTypeDisplay'),
        trailing: const Icon(Icons.chevron_right), // Indicate tappable item
        onTap: onTap, // Execute the callback when tapped
        // Optional: Add visual feedback on tap
        splashColor: Theme.of(context).primaryColorLight.withOpacity(0.3),
      ),
    );
  }
}