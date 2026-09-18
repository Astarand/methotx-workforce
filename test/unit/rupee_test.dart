import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('Test SvgImage in pdf package', () async {
    const rupeeSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 512" width="10" height="10">
  <path fill="#000000" d="M308 96c6.6 0 12-5.4 12-12V44c0-6.6-5.4-12-12-12H12C5.4 32 0 37.4 0 44v40c0 6.6 5.4 12 12 12h56.7c39.9 0 74.4 24.3 88.9 59.2H12c-6.6 0-12 5.4-12 12v40c0 6.6 5.4 12 12 12h147.2c-15.3 35.8-51 60.8-92.5 60.8H12c-6.6 0-12 5.4-12 12v44.2c0 3.2 1.3 6.3 3.6 8.5l172.5 168c4.7 4.6 12.3 4.6 17 0l31.1-30.3c4.8-4.7 4.8-12.4 0-17.1L95.5 320H156c70.8 0 130.6-47.5 148.9-112H308c6.6 0 12-5.4 12-12v-40c0-6.6-5.4-12-12-12h-47.9c-2.4-13.6-7-26.4-13.4-38H308z"/>
</svg>
''';

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (ctx) => pw.Row(
          children: [
            pw.SvgImage(svg: rupeeSvg),
            pw.SizedBox(width: 2),
            pw.Text('2,000.00'),
          ],
        ),
      ),
    );
    final bytes = await doc.save();
    expect(bytes.isNotEmpty, isTrue);
    // ignore: avoid_print
    print('SvgImage SUCCESS! Bytes: ${bytes.length}');
  });
}
