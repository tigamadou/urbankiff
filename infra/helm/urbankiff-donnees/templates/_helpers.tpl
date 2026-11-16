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

{{/* Configuration rclone du remote « rustfs » (stockage interne), par variables d'environnement. */}}
{{- define "urbankiff.rcloneRustfsEnv" -}}
- name: RCLONE_CONFIG_RUSTFS_TYPE
  value: s3
- name: RCLONE_CONFIG_RUSTFS_PROVIDER
  value: Other
- name: RCLONE_CONFIG_RUSTFS_ENDPOINT
  value: http://urbankiff-rustfs:9000
- name: RCLONE_CONFIG_RUSTFS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secretName }}
      key: MINIO_ROOT_USER
- name: RCLONE_CONFIG_RUSTFS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secretName }}
      key: MINIO_ROOT_PASSWORD
{{- end -}}

{{/* Configuration rclone du remote « wasabi ». */}}
{{- define "urbankiff.rcloneWasabiEnv" -}}
- name: RCLONE_CONFIG_WASABI_TYPE
  value: s3
- name: RCLONE_CONFIG_WASABI_PROVIDER
  value: Wasabi
- name: RCLONE_CONFIG_WASABI_ENDPOINT
  value: {{ include "urbankiff.wasabiEndpoint" . | trimPrefix "https://" }}
- name: RCLONE_CONFIG_WASABI_REGION
  value: {{ .Values.wasabi.region | quote }}
- name: RCLONE_CONFIG_WASABI_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secretName }}
      key: WASABI_ACCESS_KEY_ID
- name: RCLONE_CONFIG_WASABI_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secretName }}
      key: WASABI_SECRET_ACCESS_KEY
{{- end -}}
