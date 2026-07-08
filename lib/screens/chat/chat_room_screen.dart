import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../theme/app_theme.dart';
import '../courier/courier_request_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final int contactId;
  final String contactName;
  final int? productId;
  final ProductModel? initialBidProduct;
  final double? initialBidPrice;

  const ChatRoomScreen({
    super.key,
    required this.contactId,
    required this.contactName,
    this.productId,
    this.initialBidProduct,
    this.initialBidPrice,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _loadHistory();
      _initialized = true;
    }
  }

  void _loadHistory() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated) {
      await Provider.of<ChatProvider>(context, listen: false)
          .loadMessages(auth.currentUser!.id!, widget.contactId);
      _scrollToBottom();

      // Auto-send bid if passed from product detail screen
      if (widget.initialBidProduct != null && widget.initialBidPrice != null) {
        final chatProv = Provider.of<ChatProvider>(context, listen: false);
        await chatProv.sendBidMessage(
          senderId: auth.currentUser!.id!,
          receiverId: widget.contactId,
          productId: widget.initialBidProduct!.id!,
          bidPrice: widget.initialBidPrice!,
          productName: widget.initialBidProduct!.name,
        );
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chatProv = Provider.of<ChatProvider>(context, listen: false);

    if (auth.isAuthenticated) {
      _messageController.clear();
      await chatProv.sendMessage(
        auth.currentUser!.id!,
        widget.contactId,
        text,
      );
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final messages = chatProvider.messages;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.contactName),
            const Text(
              'Online (Simulasi)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.green),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: chatProvider.isLoading && messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == auth.currentUser?.id;
                      return _buildMessageBubble(msg, isMe);
                    },
                  ),
          ),
          // Input Bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(dynamic msg, bool isMe) {
    if (msg.isBid == 1) {
      return _buildBidBubble(msg, isMe);
    }

    final bubbleBg = isMe ? AppTheme.primaryColor : const Color(0xFFEEEEEE);
    final textStyle = TextStyle(
      color: isMe ? Colors.white : AppTheme.textPrimary,
      fontSize: 14,
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: bubbleBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg.message,
              style: textStyle,
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(msg.timestamp),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey.shade600,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBidBubble(dynamic msg, bool isMe) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final status = msg.bidStatus ?? 'pending';
    Color statusColor = Colors.orange;
    String statusLabel = 'Menunggu Konfirmasi';
    if (status == 'accepted') {
      statusColor = Colors.green;
      statusLabel = 'Tawaran Disetujui';
    } else if (status == 'rejected') {
      statusColor = Colors.red;
      statusLabel = 'Tawaran Ditolak';
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isSeller = msg.receiverId == auth.currentUser?.id;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        width: MediaQuery.of(context).size.width * 0.72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isMe ? AppTheme.primaryColor : Colors.grey.shade300, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.lightGreen : Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TAWARAN HARGA',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppTheme.primaryColor),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),
            
            // Bid details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    msg.message,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  
                  // If seller (receiver) and pending status, show buttons
                  if (isSeller && status == 'pending') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Provider.of<ChatProvider>(context, listen: false).respondToBid(
                                msg.id,
                                'rejected',
                                auth.currentUser!.id!,
                                widget.contactId,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              minimumSize: Size.zero,
                            ),
                            child: const Text('Tolak', style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Provider.of<ChatProvider>(context, listen: false).respondToBid(
                                msg.id,
                                'accepted',
                                auth.currentUser!.id!,
                                widget.contactId,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              minimumSize: Size.zero,
                            ),
                            child: const Text('Setuju', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // If buyer (sender) and accepted status, show buy now button
                  if (!isSeller && status == 'accepted') ...[
                    ElevatedButton.icon(
                      onPressed: () async {
                        final product = await Provider.of<ProductProvider>(context, listen: false)
                            .getProductById(msg.bidProductId!);
                        if (product != null && mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CourierRequestScreen(
                                product: product,
                                customPrice: msg.bidPrice,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.shopping_cart, size: 14, color: Colors.white),
                      label: const Text('Beli Sekarang', style: TextStyle(fontSize: 12, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Footer Timestamp
            Padding(
              padding: const EdgeInsets.only(right: 12.0, bottom: 8.0),
              child: Text(
                _formatTime(msg.timestamp),
                textAlign: TextAlign.end,
                style: const TextStyle(color: Colors.grey, fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBidDialog() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;

    final productProv = Provider.of<ProductProvider>(context, listen: false);
    final chatProv = Provider.of<ChatProvider>(context, listen: false);
    
    // Fetch active products of the other user (seller)
    final otherUserListings = await productProv.getUserListings(widget.contactId);
    final activeProducts = otherUserListings.where((p) => p.status == 'Tersedia').toList();

    if (activeProducts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada produk aktif dari penjual ini untuk ditawar.'),
            backgroundColor: Colors.amber,
          ),
        );
      }
      return;
    }

    ProductModel selectedProduct = activeProducts.first;
    if (widget.productId != null) {
      final matched = activeProducts.where((p) => p.id == widget.productId);
      if (matched.isNotEmpty) {
        selectedProduct = matched.first;
      }
    }

    final priceController = TextEditingController(text: selectedProduct.price.toStringAsFixed(0));

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tawar Harga Barang',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Pilih Produk:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ProductModel>(
                        value: selectedProduct,
                        isExpanded: true,
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedProduct = val;
                              priceController.text = val.price.toStringAsFixed(0);
                            });
                          }
                        },
                        items: activeProducts.map((p) {
                          return DropdownMenuItem<ProductModel>(
                            value: p,
                            child: Text(p.name, style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Harga Asli: Rp ${NumberFormat("#,##0", "id_ID").format(selectedProduct.price)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  const Text('Masukkan Harga Tawaran Anda:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    decoration: InputDecoration(
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      final bidPrice = double.tryParse(priceController.text);
                      if (bidPrice == null || bidPrice <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Masukkan harga tawaran yang valid')),
                        );
                        return;
                      }
                      if (bidPrice >= selectedProduct.price) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Harga tawaran harus lebih murah dari harga asli.')),
                        );
                        return;
                      }

                      // Close bottom sheet
                      Navigator.pop(context);

                      // Send bid message
                      chatProv.sendBidMessage(
                        senderId: auth.currentUser!.id!,
                        receiverId: widget.contactId,
                        productId: selectedProduct.id!,
                        bidPrice: bidPrice,
                        productName: selectedProduct.name,
                      );
                      _scrollToBottom();
                    },
                    child: const Text('Kirim Tawaran'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.gavel, color: AppTheme.primaryColor),
              tooltip: 'Tawar Harga',
              onPressed: _showBidDialog,
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Tulis pesan Anda...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppTheme.primaryColor,
              radius: 22,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('HH:mm').format(date);
    } catch (_) {
      return '';
    }
  }
}
