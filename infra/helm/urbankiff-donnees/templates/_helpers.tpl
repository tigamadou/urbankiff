{{/* Environnement : prod ou preprod, sinon le rendu échoue. */}}
{{- define "urbankiff.environnement" -}}
{{- if not (has .Values.environnement (list "prod" "preprod")) -}}
{{- fail "environnement doit valoir prod ou preprod" -}}
{{- end -}}
{{- .Values.environnement -}}
{{- end -}}

{{/* Libellés d'un composant : appeler avec (dict "ctx" . "composant" "redis"). */}}
{{- define "urbankiff.labels" -}}
app.kubernetes.io/name: {{ .composant }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/part-of: urbankiff
app.kubernetes.io/component: {{ .composant }}
app.kubernetes.io/managed-by: {{ .ctx.Release.Service }}
{{- end -}}

{{/* Sélecteur commun aux NetworkPolicies, Services et StatefulSets. */}}
{{- define "urbankiff.selecteur" -}}
app.kubernetes.io/part-of: urbankiff
app.kubernetes.io/component: {{ . }}
{{- end -}}

{{- define "urbankiff.securityContextPod" -}}
runAsNonRoot: true
runAsUser: 10001
runAsGroup: 10001
fsGroup: 10001
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{- define "urbankiff.securityContextConteneur" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
runAsNonRoot: true
runAsUser: 10001
capabilities:
  drop:
    - ALL
{{- end -}}

{{/* Endpoint Wasabi : valeur explicite, sinon dérivé de la région. */}}
{{- define "urbankiff.wasabiEndpoint" -}}
{{- $region := required "wasabi.region est obligatoire" .Values.wasabi.region -}}
{{- default (printf "https://s3.%s.wasabisys.com" $region) .Values.wasabi.endpoint -}}
{{- end -}}

{{- define "urbankiff.wasabiBucket" -}}
{{- required "wasabi.bucket est obligatoire" .Values.wasabi.bucket -}}
{{- end -}}

{{/* Sortie vers Internet hors plages internes (cidrExclus). */}}
{{- define "urbankiff.ipBlockInternet" -}}
ipBlock:
  cidr: 0.0.0.0/0
  except:
    {{- toYaml .Values.reseau.cidrExclus | nindent 4 }}
{{- end -}}
