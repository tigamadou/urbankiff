# Auto-test du contrôle d'iso (lancé par controle.rb, donc par `make helm-test`) : prouve qu'un écart non autorisé
# fait échouer le contrôle et que les écarts autorisés sont tolérés. Sortie non nulle au premier échec.
require 'tmpdir'
require 'yaml'
require_relative 'iso'

def verifie(description, condition)
  return puts("ok    : iso-test : #{description}") if condition

  warn "ECHEC : iso-test : #{description}"
  exit 1
end

base = { 'environnement' => 'x', 'hosts' => { 'web' => 'a', 'db' => 'b', 'stockage' => 'c' },
         'sms' => { 'actif' => true }, 'nextjs' => { 'replicas' => 1 }, 'liste' => %w[a b],
         'api' => { 'ressources' => { 'limits' => { 'memory' => '1Mi' } } },
         'postgres' => { 'ressources' => { 'requests' => { 'memory' => '1Mi' } } } }

def copie(h) = Marshal.load(Marshal.dump(h))

verifie 'valeurs identiques : aucun écart', Iso.ecarts(base, copie(base)).empty?

autorises = copie(base)
autorises['environnement'] = 'y'
autorises['hosts'] = { 'web' => 'z', 'db' => 'z', 'stockage' => 'z' }
autorises['api']['ressources']['limits']['memory'] = '9Mi'
autorises['postgres']['ressources']['requests']['memory'] = '9Mi'
verifie 'écarts autorisés tolérés', Iso.ecarts(base, autorises).empty?

{ 'sms.actif différent' => ->(h) { h['sms']['actif'] = false },
  'nextjs.replicas différent' => ->(h) { h['nextjs']['replicas'] = 2 },
  'pgadmin.image présente d\'un seul côté' => ->(h) { h['pgadmin'] = { 'image' => 'i' } },
  'valeur de liste différente' => ->(h) { h['liste'] = %w[a c] },
  'ressourcesExtra.x (sous-chaîne seulement)' => ->(h) { h['ressourcesExtra'] = { 'x' => 1 } } }.each do |nom, mutation|
  autre = copie(base)
  mutation.call(autre)
  e = Iso.ecarts(base, autre)
  verifie "écart non autorisé listé : #{nom}", !e.empty?
end

e = Iso.ecarts(base, copie(base).merge('nextjs' => { 'replicas' => 2 }))
verifie 'le chemin figure dans le message', e.first.start_with?('nextjs.replicas : prod=1 preprod=2')

verifie 'autorise? : environnement, hosts.*, segment ressources',
        Iso.autorise?('environnement') && Iso.autorise?('hosts.db') && Iso.autorise?('a.ressources.b') &&
        !Iso.autorise?('ressourcesExtra.x') && !Iso.autorise?('hostsX.a') && !Iso.autorise?('environnementY')

Dir.mktmpdir do |d|
  ecrire = lambda do |env, h|
    File.write(File.join(d, "values-#{env}.yaml"), h.to_yaml)
  end
  ecrire.call('prod', base)
  ecrire.call('preprod', base)
  verifie 'ecarts_fichiers : fichiers identiques', Iso.ecarts_fichiers(d).empty?
  autre = copie(base)
  autre['nextjs']['replicas'] = 3
  ecrire.call('preprod', autre)
  verifie 'ecarts_fichiers : écart non autorisé remonté', Iso.ecarts_fichiers(d).size == 1
  File.delete(File.join(d, 'values-preprod.yaml'))
  erreur = begin
    Iso.ecarts_fichiers(d)
    nil
  rescue StandardError => e
    e
  end
  verifie 'ecarts_fichiers : fichier absent → erreur claire', erreur&.message&.include?('values-preprod.yaml')
  File.write(File.join(d, 'values-preprod.yaml'), "a: [1\n")
  erreur = begin
    Iso.ecarts_fichiers(d)
    nil
  rescue StandardError => e
    e
  end
  verifie 'ecarts_fichiers : YAML illisible → erreur claire', erreur&.message&.include?('illisible')
end

verifie 'sms_actif? vrai', Iso.sms_actif?('sms' => { 'actif' => true })
verifie 'sms_actif? faux', !Iso.sms_actif?('sms' => { 'actif' => false })
verifie 'sms_actif? absent', !Iso.sms_actif?({})
puts 'iso-test : OK'
