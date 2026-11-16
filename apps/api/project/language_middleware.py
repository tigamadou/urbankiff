class LanguageMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        params = request.GET.dict()
        language = params.get("language", "fr")
        if language == "fr":
            language = "fr"
        else:
            language = "en"
        request.language = language

        response = self.get_response(request)
        return response
