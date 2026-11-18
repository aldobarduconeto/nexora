enum CommunityTemplate {
  general('Geral', ['geral', 'anúncios', 'mídia'], []),
  study(
    'Estudos',
    ['geral', 'dúvidas', 'materiais', 'tarefas'],
    ['Estudo em grupo', 'Plantão de dúvidas', 'Concentração'],
  ),
  gaming(
    'Games',
    ['geral', 'procurando-time', 'estratégias', 'clipes'],
    ['Lobby', 'Partidas', 'Competitivo'],
  ),
  work(
    'Trabalho',
    ['geral', 'avisos', 'projetos', 'suporte'],
    ['Reuniões', 'Colaboração', 'Conversas rápidas'],
  ),
  hobbies(
    'Hobbies',
    ['geral', 'projetos', 'inspirações', 'eventos'],
    ['Bate-papo', 'Oficina', 'Encontros'],
  ),
  events(
    'Eventos',
    ['geral', 'programação', 'avisos', 'perguntas'],
    ['Recepção', 'Palco', 'Networking'],
  ),
  technology(
    'Tecnologia',
    ['geral', 'desenvolvimento', 'recursos', 'ajuda'],
    ['Programação em grupo', 'Revisão de código', 'Demonstrações'],
  ),
  art(
    'Arte e design',
    ['geral', 'portfólios', 'inspirações', 'feedback'],
    ['Ateliê', 'Revisão de trabalhos', 'Oficina criativa'],
  ),
  music(
    'Música',
    ['geral', 'descobertas', 'produção', 'apresentações'],
    ['Ensaio', 'Escuta em grupo', 'Produção'],
  ),
  sports(
    'Esportes',
    ['geral', 'treinos', 'calendário', 'resultados'],
    ['Vestiário', 'Combinando treinos', 'Pós-jogo'],
  ),
  books(
    'Leitura',
    ['geral', 'indicações', 'leitura-do-mês', 'debates'],
    ['Clube do livro', 'Leitura em grupo', 'Debate'],
  ),
  languages(
    'Idiomas',
    ['geral', 'vocabulário', 'exercícios', 'dúvidas'],
    ['Conversação', 'Prática de pronúncia', 'Estudo em dupla'],
  ),
  family(
    'Família',
    ['geral', 'planos', 'fotos', 'lembretes'],
    ['Sala da família', 'Combinar encontros', 'Papo rápido'],
  ),
  volunteering(
    'Voluntariado',
    ['geral', 'ações', 'escalas', 'recursos'],
    ['Planejamento', 'Alinhamento de equipe', 'Recepção'],
  );

  const CommunityTemplate(this.label, this.textChannels, this.voiceLabels);

  final String label;
  final List<String> textChannels;
  final List<String> voiceLabels;
}
