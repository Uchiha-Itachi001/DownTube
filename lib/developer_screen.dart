import 'package:flutter/material.dart';
import 'dart:io';

class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Developer'),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00FF41)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0D0D), Color(0xFF1C1C1C)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const MultiRippleAvatar(),
                  const SizedBox(height: 20),
                  const Text(
                    'Developer Information',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Rich Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1F1F),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF00FF41).withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: const [
                        Text(
                          'Name: Pankoj Roy',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Email: rpankoj32@gmail.com',
                          style: TextStyle(
                            color: Color(0xFFE0E0E0),
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Role: Full-Stack Developer (Beginner in Flutter)',
                          style: TextStyle(
                            color: Color(0xFFE0E0E0),
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Skills: HTML • CSS • JavaScript • React • Node.js • Express • MongoDB • Java • C • Flutter',
                          style: TextStyle(
                            color: Color(0xFFB0B0B0),
                            fontSize: 14,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'About: Passionate about coding, teaching, and building creative tools and apps for fun. Enjoy learning new technologies, solving problems, and sharing knowledge with others. Currently exploring Flutter and full-stack development projects.',
                          style: TextStyle(
                            color: Color(0xFFB0B0B0),
                            fontSize: 14,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Social / Contact Links
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SocialButton(
                        icon: Icons.facebook,
                        label: 'Facebook',
                        color: const Color(0xFF1877F2),
                        onTap:
                            () => _openExternal(
                              context,
                              'https://www.facebook.com/share/16845vkjeU/',
                            ),
                      ),
                      const SizedBox(width: 12),
                      _SocialButton(
                        icon: Icons.camera_alt,
                        label: 'Instagram',
                        color: const Color(0xFFE1306C),
                        onTap:
                            () => _openExternal(
                              context,
                              'https://www.instagram.com/rpankoj32?igsh=cHp5Ymx5MGNkdjFz&utm_source=ig_contact_invite ',
                            ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _HoverButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icons.home,
                    label: 'Back to Home',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Multi ripple avatar widget with hover scale
class MultiRippleAvatar extends StatefulWidget {
  const MultiRippleAvatar({super.key});

  @override
  State<MultiRippleAvatar> createState() => _MultiRippleAvatarState();
}

class _MultiRippleAvatarState extends State<MultiRippleAvatar>
    with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;
  late AnimationController _controller3;
  bool isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _controller2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _controller2.repeat();
    });
    _controller3 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _controller3.repeat();
    });
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    super.dispose();
  }

  Widget _buildRipple(AnimationController controller) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        double scale = 1 + controller.value * 2.1;
        double opacity = (1 - controller.value) * 0.4;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00FF41).withOpacity(opacity),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _buildRipple(_controller1),
        _buildRipple(_controller2),
        _buildRipple(_controller3),
        MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: AnimatedScale(
            scale: isHovered ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00FF41), Color(0xFF00CC33)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FF41).withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assetes/images/developer.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom Hoverable Button
class _HoverButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _HoverButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

/// Social Button with Hover Effect
class _SocialButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform:
            _isHovered ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color:
                  _isHovered
                      ? widget.color.withOpacity(0.25)
                      : widget.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    _isHovered
                        ? widget.color.withOpacity(0.6)
                        : widget.color.withOpacity(0.3),
                width: _isHovered ? 2 : 1,
              ),
              boxShadow:
                  _isHovered
                      ? [
                        BoxShadow(
                          color: widget.color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : null,
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  color: widget.color,
                  size: _isHovered ? 20 : 18,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: _isHovered ? FontWeight.w700 : FontWeight.w600,
                    fontSize: _isHovered ? 13 : 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openExternal(BuildContext context, String url) async {
  try {
    if (Platform.isWindows) {
      // start "" "url"
      await Process.run('cmd', ['/c', 'start', '', url]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening links is not supported on this platform.'),
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Failed to open: $e')));
  }
}

class _HoverButtonState extends State<_HoverButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(isHovered ? 1.05 : 1.0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00FF41), Color(0xFF00CC33)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            if (isHovered)
              BoxShadow(
                color: const Color(0xFF00FF41).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: ElevatedButton.icon(
          icon: Icon(widget.icon, size: 20, color: Colors.black),
          label: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          onPressed: widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          ),
        ),
      ),
    );
  }
}
