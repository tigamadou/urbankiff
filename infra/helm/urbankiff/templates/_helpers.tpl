{{/* Environnement : prod ou preprod, sinon le rendu échoue. */}}
{{- define "urbankiff.environnement" -}}
{{- if not (has .Values.environnement (list "prod" "preprod")) -}}
{{- fail "environnement doit valoir prod ou preprod" -}}
{{- end -}}
{{- .Values.environnement -}}
{{- end -}}

{{/* Libellés d'un composant : appeler avec (dict "ctx" . "composant" "api"). */}}
{{- define "urbankiff.labels" -}}
app.kubernetes.io/name: {{ .composant }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/part-of: urbankiff
app.kubernetes.io/component: {{ .composant }}
app.kubernetes.io/managed-by: {{ .ctx.Release.Service }}
{{- end -}}

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

{{/* Étiquette de l'image : l'api prend la version, Next et panel ajoutent -<environnement>. */}}
{{- define "urbankiff.etiquette" -}}
{{- required "image.etiquette est obligatoire (version de la release)" .Values.image.etiquette -}}
{{- end -}}

{{- define "urbankiff.imageApi" -}}
{{- printf "%s/urbankiff-api:%s" .Values.image.depot (include "urbankiff.etiquette" .) -}}
{{- end -}}

{{- define "urbankiff.imageFront" -}}
{{- printf "%s/urbankiff-%s:%s-%s" .ctx.Values.image.depot .nom (include "urbankiff.etiquette" .ctx) .ctx.Values.environnement -}}
{{- end -}}

{{- define "urbankiff.imagePullSecrets" -}}
{{- if .Values.image.secretTirage }}
imagePullSecrets:
  - name: {{ .Values.image.secretTirage }}
{{- end }}
{{- end -}}

{{/* envFrom commun à l'api, aux workers et aux migrations (spec § 8.5, A5). */}}
{{- define "urbankiff.envFrom" -}}
- secretRef:
    name: {{ .Values.secretName }}
- configMapRef:
    name: {{ .Values.configName }}
{{- end -}}

{{/*
Variables explicites de l'api, des workers et des migrations. Elles l'emportent sur envFrom.
REDIS_PASSWORD est déclaré avant REDIS_ENDPOINT : Kubernetes n'étend $(VAR) que vers les variables déjà déclarées.
*/}}
{{- define "urbankiff.envApp" -}}
- name: POSTGRES_USER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secretBase }}
      key: username
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secretBase }}
      key: password
- name: POSTGRES_DB
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secretBase }}
      key: dbname
- name: POSTGRES_HOST
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secretBase }}
      key: host
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secretName }}
      key: REDIS_PASSWORD
- name: REDIS_ENDPOINT
  value: redis://:$(REDIS_PASSWORD)@urbankiff-redis:6379/0
- name: MINIO_ENDPOINT
  value: urbankiff-rustfs:9000
{{- if .Values.sms.actif }}
- name: TWILIO_ACCOUNT_SID
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secretName }}
      key: TWILIO_ACCOUNT_SID
- name: TWILIO_AUTH_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secretName }}
      key: TWILIO_AUTH_TOKEN
{{- else }}
- name: TWILIO_ACCOUNT_SID
  value: desactive
- name: TWILIO_AUTH_TOKEN
  value: desactive
{{- end }}
{{- end -}}
