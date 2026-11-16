# Contrôles transverses sur le rendu des deux charts pour prod et preprod (lancés par `make helm-test`, dans un
# conteneur Ruby, bibliothèque standard seulement). Chaque contrôle liste ses violations ; une seule suffit à échouer.
# Entrées : /rendu/<chart>-<env>.yaml (rendus), /charts (charts, lecture seule).
require 'yaml'

SECRETS_INVENTAIRE = '/charts/tests-transverses/secrets-inventaire.txt'
# Quota de la preprod (spec § 8.5, A9) en Mi : posé par le rôle plateforme d'Ansible, pas par les charts
QUOTA_PREPROD_MI = 2048
CIDR_POD = '10.42.0.0/16'
CIDR_SERVICE = '10.43.0.0/16'
NAMESPACES_AUTORISES = %w[kube-system plateforme].freeze
TWILIO = %w[TWILIO_ACCOUNT_SID TWILIO_AUTH_TOKEN].freeze

$echecs = 0

def verifie(description, violations)
  if violations.empty?
    puts "ok    : #{description}"
  else
    warn "ECHEC : #{description}"
    violations.each { |v| warn "    #{v}" }
    $echecs += 1
  end
end

def charge(env)
  %W[/rendu/urbankiff-donnees-#{env}.yaml /rendu/urbankiff-#{env}.yaml].flat_map do |f|
    YAML.load_stream(File.read(f)).compact
  end
end

def nom(doc) = "#{doc['kind']}/#{doc.dig('metadata', 'name')}"

# [nom, spec du pod, métadonnées du gabarit de pod] pour Deployment, StatefulSet, Job, CronJob
def pods(docs)
  docs.filter_map do |d|
    gabarit = case d['kind']
              when 'Deployment', 'StatefulSet', 'Job' then d.dig('spec', 'template')
              when 'CronJob' then d.dig('spec', 'jobTemplate', 'spec', 'template')
              end
    [nom(d), gabarit['spec'], gabarit['metadata'] || {}, d['kind']] if gabarit
  end
end

def conteneurs(spec) = (spec['containers'] || []) + (spec['initContainers'] || [])

# Parcourt récursivement un document et rend les Hash qui possèdent la clé donnée
def trouve(noeud, cle, &bloc)
  case noeud
  when Hash
    bloc.call(noeud[cle]) if noeud.key?(cle)
    noeud.each_value { |v| trouve(v, cle, &bloc) }
  when Array
    noeud.each { |v| trouve(v, cle, &bloc) }
  end
end

def chaines(noeud, &bloc)
  case noeud
  when Hash then noeud.each_value { |v| chaines(v, &bloc) }
  when Array then noeud.each { |v| chaines(v, &bloc) }
  when String then bloc.call(noeud)
  end
end

def mi(valeur)
  raise "unité inattendue : #{valeur}" unless valeur.to_s =~ /\A(\d+)Mi\z/
  Regexp.last_match(1).to_i
end

noms_secrets = File.readlines(SECRETS_INVENTAIRE, chomp: true).reject { |l| l.strip.empty? || l.start_with?('#') }.map { |l| l.split.first }

%w[prod preprod].each do |env|
  puts "== #{env}"
  docs = charge(env)
  tous_pods = pods(docs)

  verifie "#{env} : pods durcis (non root, UID non nul, seccomp, sans jeton de compte de service)",
          tous_pods.filter_map { |n, spec, _, _|
            sc = spec['securityContext'] || {}
            n unless sc['runAsNonRoot'] == true && sc['runAsUser'].to_i > 0 &&
                     sc.dig('seccompProfile', 'type') == 'RuntimeDefault' && spec['automountServiceAccountToken'] == false
          }

  verifie "#{env} : conteneurs (init compris) durcis, avec requests et limits mémoire",
          tous_pods.flat_map { |n, spec, _, _|
            conteneurs(spec).filter_map { |c|
              sc = c['securityContext'] || {}
              ok = sc['allowPrivilegeEscalation'] == false && sc['readOnlyRootFilesystem'] == true &&
                   sc['runAsNonRoot'] == true && (sc.dig('capabilities', 'drop') || []).include?('ALL') &&
                   c.dig('resources', 'requests', 'memory') && c.dig('resources', 'limits', 'memory')
              "#{n} / #{c['name']}" unless ok
            }
          }

  verifie "#{env} : Deployments et StatefulSets avec sondes, empreinte des secrets et libellé part-of",
          tous_pods.select { |_, _, _, k| %w[Deployment StatefulSet].include?(k) }.flat_map { |n, spec, meta, _|
            spec['containers'].filter_map { |c|
              ok = c['readinessProbe'] && c['livenessProbe'] &&
                   meta.dig('annotations', 'urbankiff.com/secrets-checksum') &&
                   meta.dig('labels', 'app.kubernetes.io/part-of') == 'urbankiff'
              "#{n} / #{c['name']}" unless ok
            }
          }

  verifie "#{env} : Jobs et CronJobs avec libellés part-of et component",
          tous_pods.select { |_, _, _, k| %w[Job CronJob].include?(k) }.filter_map { |n, _, meta, _|
            l = meta['labels'] || {}
            n unless l['app.kubernetes.io/part-of'] == 'urbankiff' && l['app.kubernetes.io/component']
          }

  verifie "#{env} : Cluster CloudNativePG durci, limité en mémoire, libellé part-of, sans annotation d'hibernation",
          docs.select { |d| d['kind'] == 'Cluster' }.filter_map { |d|
            s = d['spec']
            ok = s.dig('securityContext', 'readOnlyRootFilesystem') == true &&
                 s.dig('securityContext', 'allowPrivilegeEscalation') == false &&
                 s.dig('podSecurityContext', 'runAsNonRoot') == true &&
                 s.dig('podSecurityContext', 'runAsUser').to_i > 0 &&
                 s.dig('podSecurityContext', 'seccompProfile', 'type') == 'RuntimeDefault' &&
                 s.dig('resources', 'limits', 'memory') && s.dig('resources', 'requests', 'memory') &&
                 s.dig('inheritedMetadata', 'labels', 'app.kubernetes.io/part-of') == 'urbankiff' &&
                 !(d.dig('metadata', 'annotations') || {}).key?('cnpg.io/hibernation')
            nom(d) unless ok
          }

  politiques = docs.select { |d| d['kind'] == 'NetworkPolicy' }
  verifie "#{env} : il y a des NetworkPolicy", politiques.empty? ? ['aucune'] : []

  v = []
  politiques.each do |p|
    trouve(p, 'namespaceSelector') do |sel|
      cible = sel.dig('matchLabels', 'kubernetes.io/metadata.name')
      v << "#{p['metadata']['name']} : namespaceSelector vers #{cible.inspect}" unless NAMESPACES_AUTORISES.include?(cible)
    end
  end
  verifie "#{env} : aucune NetworkPolicy ne vise un namespace hors kube-system et plateforme", v

  v = []
  politiques.each { |p| chaines(p) { |s| v << "#{p['metadata']['name']} : #{s}" if %w[prod preprod].include?(s) } }
  verifie "#{env} : aucune NetworkPolicy ne cite prod ou preprod", v

  v = []
  politiques.each do |p|
    trouve(p, 'ipBlock') do |ip|
      next if ip['cidr'].to_s.end_with?('/32') # une seule IP (nœud) : rien à exclure, et `except` hors du cidr serait refusé

      exceptions = ip['except'] || []
      v << "#{p['metadata']['name']} : #{ip['cidr']}" unless exceptions.include?(CIDR_POD) && exceptions.include?(CIDR_SERVICE)
    end
  end
  verifie "#{env} : toute règle ipBlock exclut les plages des pods et des services k3s", v

  verifie "#{env} : aucun Secret rendu par les charts", docs.select { |d| d['kind'] == 'Secret' }.map { |d| nom(d) }

  v = []
  tous_pods.each do |n, spec, _, _|
    conteneurs(spec).each do |c|
      (c['env'] || []).each do |e|
        next unless e.key?('value') && (noms_secrets.include?(e['name']))
        inerte = TWILIO.include?(e['name']) && e['value'] == 'desactive'
        v << "#{n} : #{e['name']}" unless inerte
      end
    end
  end
  verifie "#{env} : aucune clé de l'inventaire des secrets en value: (hors valeurs inertes Twilio)", v

  v = []
  tous_pods.each do |n, spec, _, _|
    conteneurs(spec).each do |c|
      ((c['command'] || []) + (c['args'] || [])).each do |a|
        v << "#{n} / #{c['name']}" if a =~ /(password|secret|token|key)\s*=\s*[^\s$]/i
      end
    end
  end
  verifie "#{env} : aucun mot de passe, secret ou jeton écrit dans command ou args", v

  verifie "#{env} : hôtes publics, aucun hôte de stockage",
          docs.select { |d| d['kind'] == 'Ingress' }.flat_map { |d| d['spec']['rules'].map { |r| r['host'] } }.select { |h| h =~ /(\A|\.)s3/ }
end

puts '== Twilio'
def cles_secret(docs)
  cles = []
  docs.each { |d| trouve(d, 'secretKeyRef') { |r| cles << r['key'] } }
  cles.uniq
end
verifie 'preprod : aucune référence aux clés TWILIO_* du Secret', cles_secret(charge('preprod')).grep(/\ATWILIO_/)
inertes = []
charge('preprod').each { |d| pods([d]).each { |n, spec, _, _| conteneurs(spec).each { |c| (c['env'] || []).each { |e| inertes << "#{n} : #{e['name']}" if TWILIO.include?(e['name']) && e['value'] != 'desactive' } } } }
verifie 'preprod : valeurs Twilio inertes', inertes
verifie 'prod : TWILIO_ACCOUNT_SID et TWILIO_AUTH_TOKEN référencés par le Secret',
        (TWILIO - cles_secret(charge('prod'))).map { |k| "#{k} absent" }

puts '== Quota de la preprod'
docs = charge('preprod')
regime = docs.sum do |d|
  case d['kind']
  when 'Deployment', 'StatefulSet'
    (d['spec']['replicas'] || 1) * d['spec']['template']['spec']['containers'].sum { |c| mi(c.dig('resources', 'limits', 'memory')) }
  when 'Cluster'
    d['spec']['instances'] * mi(d.dig('spec', 'resources', 'limits', 'memory'))
  else 0
  end
end
plus_gros_job = pods(docs).select { |_, _, _, k| %w[Job CronJob].include?(k) }.flat_map { |_, spec, _, _| conteneurs(spec).map { |c| mi(c.dig('resources', 'limits', 'memory')) } }.max || 0
puts "limites en régime établi : #{regime} Mi ; plus gros Job : #{plus_gros_job} Mi ; quota : #{QUOTA_PREPROD_MI} Mi"
total = regime + plus_gros_job
verifie 'preprod : limites mémoire en régime établi plus le plus gros Job sous le quota',
        total <= QUOTA_PREPROD_MI ? [] : ["#{total} Mi > #{QUOTA_PREPROD_MI} Mi"]

# Marge assumée : le Job de migrations (crochet de déploiement) et le CronJob rclone (planifié la nuit) peuvent se
# chevaucher exceptionnellement ; au-delà du quota, le pod du Job est refusé puis relancé (backoffLimit), et le CronJob
# saute son tour. On borne donc le chevauchement à un seul CronJob (concurrencyPolicy: Forbid) et on affiche le pire cas.
crons = docs.select { |d| d['kind'] == 'CronJob' }
verifie 'preprod : les CronJobs interdisent l\'exécution concurrente (concurrencyPolicy: Forbid)',
        crons.reject { |d| d.dig('spec', 'concurrencyPolicy') == 'Forbid' }.map { |d| nom(d) }
limite_cron = crons.flat_map { |d| conteneurs(d.dig('spec', 'jobTemplate', 'spec', 'template', 'spec')).map { |c| mi(c.dig('resources', 'limits', 'memory')) } }.max || 0
migrations = pods(docs).select { |n, _, _, _| n.include?('migrations') }.flat_map { |_, spec, _, _| conteneurs(spec).map { |c| mi(c.dig('resources', 'limits', 'memory')) } }.max || 0
puts "pire chevauchement (migrations + CronJob) : #{regime + migrations + limite_cron} Mi pour un quota de #{QUOTA_PREPROD_MI} Mi (dépassement toléré, voir kubernetes.md)"

if $echecs.positive?
  warn "#{$echecs} contrôle(s) transverse(s) en échec"
  exit 1
end
puts 'contrôles transverses : OK'
