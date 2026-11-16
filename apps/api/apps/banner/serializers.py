from rest_framework import serializers
from .models import Campaign, Media


class MediaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Media
        fields = ['uuid', 'type', 'file', 'device', 'url']


class CampaignSerializer(serializers.ModelSerializer):
    medias = MediaSerializer(many=True)

    class Meta:
        model = Campaign
        fields = ['id', 'uuid', 'medias']

    def create(self, validated_data):
        # Extract the nested 'medias' data
        medias_data = validated_data.pop('medias', [])
        # Create the campaign instance
        campaign = Campaign.objects.create(**validated_data)

        # Create associated Media objects
        for media_data in medias_data:
            Media.objects.create(campaign=campaign, **media_data)

        return campaign

    def update(self, instance, validated_data):
        # Update the campaign fields
        instance.uuid = validated_data.get('uuid', instance.uuid)
        instance.save()

        # Update or create the associated Media objects
        medias_data = validated_data.pop('medias', [])
        existing_media_uuids = {media.uuid for media in instance.medias.all()}

        for media_data in medias_data:
            media_uuid = media_data.get('uuid')
            if media_uuid in existing_media_uuids:
                # Update existing media
                media_instance = Media.objects.get(uuid=media_uuid, campaign=instance)
                for attr, value in media_data.items():
                    setattr(media_instance, attr, value)
                media_instance.save()
            else:
                # Create new media
                Media.objects.create(campaign=instance, **media_data)

        return instance
