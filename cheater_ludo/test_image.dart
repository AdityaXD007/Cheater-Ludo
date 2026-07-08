import 'dart:io';

void main() async {
  final file = File('assets/dice/final/face_1.png');
  final bytes = await file.readAsBytes();
  
  // Quick hack to read PNG IHDR chunk width and height
  // IHDR is at byte offset 16-24
  if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
    int width = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
    int height = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
    print('Dimensions: ${width}x$height');
  } else {
    print('Not a valid PNG');
  }
}
