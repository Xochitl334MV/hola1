import 'package:flutter/material.dart';

class AdaptiveNavigation extends StatelessWidget {
  const AdaptiveNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final void Function(int index) onDestinationSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, dimens) {
        // Tablet Layout
        if (dimens.maxWidth >= 600) { // Add this line
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: dimens.maxWidth >= 800,
                  minExtendedWidth: 180,
                  destinations: destinations
                      .map((e) => NavigationRailDestination(
                            icon: e.icon,
                            label: Text(e.label),
                          ))
                      .toList(),
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                ),
                Expanded(child: child),
              ],
            ),
          );
        } // Add this line
        // Add maxWidth constraint check
        // Add from here...
        return Scaffold(
          body: child,
          bottomNavigationBar: NavigationBar(
            destinations: destinations,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
          ),
        );
        // ... To here.
        // Add closing curly bracket

        // Add return for mobile layout
      },
    );
  }
}
