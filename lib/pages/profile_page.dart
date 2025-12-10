import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  // 1. Function to open the website
  Future<void> _launchGalleryURL() async {
    final Uri url = Uri.parse('https://swoosh-tennis.netlify.app/gallery.html');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get current user from Firebase
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? "Guest";
    final photoUrl = user?.photoURL;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          CircleAvatar(
            radius: 50,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            backgroundColor: Colors.blueAccent.shade100,
            child: photoUrl == null
                ? const Icon(Icons.person, size: 50, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 16),
          
          // Email
          Text(
            email,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Swoosh Member",
            style: TextStyle(color: Colors.grey),
          ),
          
          const SizedBox(height: 40),

          // --- WEB GALLERY LINK ---
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 30),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              onTap: _launchGalleryURL,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.public, color: Colors.blueAccent, size: 30),
                    ),
                    const SizedBox(width: 20),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Web Gallery",
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                          Text(
                            "View your videos on the big screen",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Optional: duplicate Logout button here for easy access
          TextButton.icon(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // Navigation back to login is handled by AppShell or Main wrapper usually,
              // but since AppShell has the logout logic in the AppBar, 
              // we can just let the user use that or replicate the logic here.
              // For now, let's just trigger the parent rebuild or rely on Auth State stream.
            }, 
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            label: const Text("Sign Out", style: TextStyle(color: Colors.redAccent)),
          )
        ],
      ),
    );
  }
}