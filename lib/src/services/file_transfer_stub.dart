class FileTransferService {
  FileTransferService({required this.send, required this.notice});
  final Future<void> Function(String) send;
  final void Function(String) notice;
  Future<void> pickAndSend() async =>
      notice('O envio de arquivos está disponível no aplicativo instalado.');
  Future<void> receive(String text) async {}
  Future<void> abort() async {}
  Future<void> close() async {}
}
