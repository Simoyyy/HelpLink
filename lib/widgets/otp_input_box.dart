import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OtpInputBox extends StatefulWidget {
  final void Function(String code) onChanged;
  final Color activeColor;

  const OtpInputBox({
    super.key,
    required this.onChanged,
    required this.activeColor,
  });

  @override
  State<OtpInputBox> createState() => OtpInputBoxState();
}

class OtpInputBoxState extends State<OtpInputBox> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When Android backgrounds the app the IME disconnects, but FocusNode
    // still reports hasFocus=true. requestFocus() is then a no-op and the
    // keyboard never reappears. Unfocusing on resume resets the state so
    // the next tap triggers a fresh IME connection.
    if (state == AppLifecycleState.resumed && _focusNode.hasFocus) {
      _focusNode.unfocus();
    }
  }

  void clear() {
    _controller.clear();
    setState(() {});
    _focusNode.requestFocus();
    widget.onChanged('');
  }

  void fill(String code) {
    _controller.text = code;
    setState(() {});
    widget.onChanged(code);
  }

  @override
  Widget build(BuildContext context) {
    final code = _controller.text;
    final isFocused = _focusNode.hasFocus;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hidden but active TextField — captures keyboard input.
        // SizedBox(height:0) keeps the field in the render tree so Android's
        // IME connects properly (Offstage drops it from the IME connection).
        // ClipRect prevents the text from visually overflowing the 0-height bounds.
        ClipRect(
          child: SizedBox(
            height: 0,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLength: 6,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
              onChanged: (v) {
                setState(() {});
                widget.onChanged(v);
              },
            ),
          ),
        ),
        // Visual: single box with 6 underline slots
        GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isFocused
                    ? widget.activeColor
                    : const Color(0xFFE2E8F0),
                width: isFocused ? 2 : 1.5,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: widget.activeColor.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                6,
                (i) => _buildSlot(
                  code.length > i ? code[i] : null,
                  code.length == i && isFocused,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlot(String? digit, bool isCursor) {
    return SizedBox(
      width: 36,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            digit ?? ' ',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: digit != null ? widget.activeColor : Colors.transparent,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            decoration: BoxDecoration(
              color: isCursor
                  ? widget.activeColor
                  : (digit != null
                      ? widget.activeColor.withValues(alpha: 0.6)
                      : const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}
