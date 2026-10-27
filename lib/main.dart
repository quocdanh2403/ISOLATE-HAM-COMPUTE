
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

int heavyTask(int n) {
  var sum = 0;
  for (var i = 0; i < n; i++) {
    sum += i % 7;
  }
  return sum;
}

// Số lần lặp. Nếu máy bạn tính xong quá nhanh (dưới 1 giây) thì tăng lên,
// nếu quá lâu thì giảm xuống. Với 500000000, kết quả đúng là 1499999994.
const int kIterations = 500000000;

// ---------------------------------------------------------------
// 2. ỨNG DỤNG
// ---------------------------------------------------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      // Bỏ dấu // dòng dưới để hiện thanh đo khung hình (cột đỏ = khung bị trễ):
      // showPerformanceOverlay: true,
      home: DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  String _result = 'Chưa chạy';
  int? _elapsedMs; // thời gian tính, đơn vị mili giây
  bool _running = false;

  // -------------------------------------------------------------
  // NÚT 1: chạy trực tiếp trên Main Thread
  // -------------------------------------------------------------
  Future<void> _runOnMainThread() async {
    setState(() {
      _running = true;
      _result = 'Đang tính trên Main Thread...';
    });

    // Chờ 100 ms để Flutter kịp vẽ dòng chữ "Đang tính..." lên màn hình.
    // Nếu không có dòng này, heavyTask chạy ngay và chiếm luồng trước khi
    // khung hình mới kịp được vẽ.
    await Future.delayed(const Duration(milliseconds: 100));

    final stopwatch = Stopwatch()..start();
    final result = heavyTask(kIterations); // <-- chạy NGAY trên luồng chính
    stopwatch.stop();

    // Từ lúc heavyTask bắt đầu đến lúc xong, luồng chính bị chiếm:
    // spinner đứng hình, các nút không phản hồi.

    if (!mounted) return;
    setState(() {
      _running = false;
      _result = 'Kết quả: $result';
      _elapsedMs = stopwatch.elapsedMilliseconds;
    });
  }

  // -------------------------------------------------------------
  // NÚT 2: chạy bằng compute (Isolate nền)
  // -------------------------------------------------------------
  Future<void> _runWithCompute() async {
    setState(() {
      _running = true;
      _result = 'Đang tính bằng compute...';
    });

    final stopwatch = Stopwatch()..start();

    // compute tạo một Isolate mới, chạy heavyTask(kIterations) ở đó,
    // rồi gửi kết quả về. Trong lúc chờ (await), luồng chính vẫn rảnh
    // nên Flutter tiếp tục vẽ spinner đều đặn.
    final result = await compute(heavyTask, kIterations);
    stopwatch.stop();

    // Sau await, màn hình có thể đã bị đóng. Kiểm tra trước khi setState.
    if (!mounted) return;
    setState(() {
      _running = false;
      _result = 'Kết quả: $result';
      _elapsedMs = stopwatch.elapsedMilliseconds;
    });
  }

  // -------------------------------------------------------------
  // GIAO DIỆN
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demo Isolate & compute')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Spinner quay liên tục: đây là "máy đo" độ mượt của giao diện.
            // Nó đứng hình lúc nào nghĩa là luồng chính đang bị chiếm.
            const CircularProgressIndicator(),
            const SizedBox(height: 32),

            ElevatedButton(
              // onPressed: null nghĩa là nút bị vô hiệu hóa khi đang tính
              onPressed: _running ? null : _runOnMainThread,
              child: const Text('Nút 1: Chạy trên Main Thread'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _running ? null : _runWithCompute,
              child: const Text('Nút 2: Chạy bằng compute'),
            ),
            const SizedBox(height: 24),

            Text(_result, style: const TextStyle(fontSize: 18)),
            if (_elapsedMs != null)
              Text(
                'Thời gian tính: $_elapsedMs ms',
                style: const TextStyle(fontSize: 14),
              ),
          ],
        ),
      ),
    );
  }
}
