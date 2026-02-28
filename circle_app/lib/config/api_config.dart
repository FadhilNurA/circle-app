class ApiConfig {
  // Change this to your actual backend URL
  // For Android emulator use: http://10.0.2.2:3000
  // For iOS simulator use: http://localhost:3000
  // For physical device use your computer's IP: http://192.168.x.x:3000
  static const String baseUrl = 'http://localhost:3000';

  // Auth endpoints
  static const String register = '$baseUrl/api/auth/register';
  static const String login = '$baseUrl/api/auth/login';
  static const String logout = '$baseUrl/api/auth/logout';
  static const String me = '$baseUrl/api/auth/me';
  static const String refresh = '$baseUrl/api/auth/refresh';

  // User endpoints
  static const String searchUsers = '$baseUrl/api/users/search';

  // Friend endpoints
  static const String friends = '$baseUrl/api/friends';
  static const String friendRequests = '$baseUrl/api/friends/requests';
  static String friendship(String id) => '$baseUrl/api/friends/$id';

  // Group endpoints
  static const String groups = '$baseUrl/api/groups';
  static String group(String id) => '$baseUrl/api/groups/$id';
  static String groupMembers(String id) => '$baseUrl/api/groups/$id/members';
  static String groupMessages(String id) => '$baseUrl/api/groups/$id/messages';

  // Receipt/Bill endpoints
  static String receipts(String groupId) =>
      '$baseUrl/api/groups/$groupId/receipts';
  static String receipt(String groupId, String receiptId) =>
      '$baseUrl/api/groups/$groupId/receipts/$receiptId';
  static String receiptItems(String groupId, String receiptId) =>
      '$baseUrl/api/groups/$groupId/receipts/$receiptId/items';
  static String splitBill(String groupId, String receiptId) =>
      '$baseUrl/api/groups/$groupId/receipts/$receiptId/split';
  static String approveBill(String groupId, String receiptId) =>
      '$baseUrl/api/groups/$groupId/receipts/$receiptId/approve';

  // Scan Receipt (AI) endpoint
  static const String scanReceipt = '$baseUrl/api/scan-receipt';

  // Spotify endpoints
  static const String spotifyCreateJam = '$baseUrl/api/spotify/create-jam';

  // Socket.IO (for lyrics sync)
  static const String socketUrl = baseUrl; // same host as backend
}
