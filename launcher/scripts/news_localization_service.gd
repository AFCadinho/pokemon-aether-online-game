class_name LauncherNewsLocalizationService
extends RefCounted


static func resolve_items(news_data: Dictionary, locale: String) -> Array[Dictionary]:
	var source_data := _resolve_locale_bucket(news_data, locale)
	var item_variants: Variant = source_data.get("items") if source_data.has("items") else source_data.get("articles", [])
	var resolved: Array[Dictionary] = []
	if not item_variants is Array:
		return resolved

	for item_variant: Variant in item_variants:
		if not item_variant is Dictionary:
			continue
		var item := _resolve_item(item_variant as Dictionary, locale)
		if not str(item.get("title", "")).strip_edges().is_empty():
			resolved.append(item)
	return resolved


static func _resolve_locale_bucket(news_data: Dictionary, locale: String) -> Dictionary:
	var buckets_variant: Variant = news_data.get("locales", {})
	if not buckets_variant is Dictionary:
		return news_data
	var buckets := buckets_variant as Dictionary
	for candidate: String in _locale_candidates(locale):
		var bucket: Variant = buckets.get(candidate)
		if bucket is Dictionary:
			return bucket as Dictionary
		if bucket is Array:
			return {"items": bucket}
	return news_data


static func _resolve_item(item: Dictionary, locale: String) -> Dictionary:
	var localized := item
	var translations_variant: Variant = item.get("localizations", item.get("translations", {}))
	if translations_variant is Dictionary:
		var translations := translations_variant as Dictionary
		for candidate: String in _locale_candidates(locale):
			var translation: Variant = translations.get(candidate)
			if translation is Dictionary:
				localized = item.merged(translation as Dictionary, true)
				break

	return {
		"title": str(localized.get("title", "")).strip_edges(),
		"description": str(localized.get("description", localized.get("summary", ""))).strip_edges(),
		"url": str(localized.get("url", localized.get("externalLink", ""))).strip_edges(),
		"date": str(localized.get("date", "")).strip_edges(),
	}


static func _locale_candidates(locale: String) -> Array[String]:
	var normalized := locale.strip_edges().replace("_", "-")
	var candidates: Array[String] = []
	for candidate: String in [normalized, normalized.replace("-", "_"), normalized.get_slice("-", 0), "en"]:
		if not candidate.is_empty() and not candidates.has(candidate):
			candidates.append(candidate)
	return candidates
