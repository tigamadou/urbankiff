# Contrôle d'iso entre values-prod.yaml et values-preprod.yaml d'un chart (spec § 5.1, § 8.3 « Iso »).
# Bibliothèque standard seulement. Les deux fichiers sont comparés en entier, clés présentes d'un seul côté comprises.
require 'yaml'

module Iso
  # Seuls écarts permis : le nom de l'environnement, les hôtes publics, et toute clé sous un segment `ressources`
  # (la mémoire de la preprod est dimensionnée à part). Ne rien ajouter ici sans modifier le contrat de la spec.
  ECARTS_AUTORISES = ->(chemin) { chemin == 'environnement' || chemin.start_with?('hosts.') || chemin.split('.').include?('ressources') }

  module_function

  def autorise?(chemin) = ECARTS_AUTORISES.call(chemin)

  # Hash imbriqués aplatis en chemins pointés ; tableaux et scalaires sont des feuilles
  def aplati(noeud, prefixe = nil, sortie = {})
    if noeud.is_a?(Hash) && !noeud.empty?
      noeud.each { |k, v| aplati(v, [prefixe, k].compact.join('.'), sortie) }
    else
      sortie[prefixe] = noeud
    end
    sortie
  end

  def ecarts(prod, preprod)
    a = aplati(prod)
    b = aplati(preprod)
    (a.keys | b.keys).sort.filter_map do |chemin|
      next if autorise?(chemin)
      next if a.key?(chemin) && b.key?(chemin) && a[chemin] == b[chemin]

      "#{chemin} : prod=#{a.key?(chemin) ? a[chemin].inspect : '(absent)'} preprod=#{b.key?(chemin) ? b[chemin].inspect : '(absent)'}"
    end
  end

  def lis(fichier)
    raise "fichier de valeurs absent : #{fichier}" unless File.file?(fichier)

    YAML.safe_load(File.read(fichier)) || {}
  rescue Psych::Exception => e
    raise "fichier de valeurs illisible : #{fichier} (#{e.message})"
  end

  def ecarts_fichiers(dossier_chart)
    ecarts(lis(File.join(dossier_chart, 'values-prod.yaml')), lis(File.join(dossier_chart, 'values-preprod.yaml')))
  end

  def sms_actif?(valeurs) = valeurs.dig('sms', 'actif') == true
end
