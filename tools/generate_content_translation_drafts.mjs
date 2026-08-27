#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import {fileURLToPath} from "node:url";

const ACCEPT_FLAG = "--accept-machine-translation";
const ITEMS_ONLY_FLAG = "--items-only";
const LOCALE_FLAG = "--locale";
const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const generatedDir = path.join(projectRoot, "localization/content/generated");
const englishSourcePath = path.join(generatedDir, "en.json");
const generatedItemDir = path.join(projectRoot, "localization/items/generated");
const englishItemSourcePath = path.join(generatedItemDir, "en.json");
const terminologyDir = path.join(projectRoot, "localization/terminology");
const targets = [
	{locale: "nl", translationLanguage: "nl"},
	{locale: "pt_BR", translationLanguage: "pt"},
	{locale: "zh_CN", translationLanguage: "zh-CN"},
];
const batchSize = 18;
const concurrency = 4;

if (!process.argv.includes(ACCEPT_FLAG)) {
	console.error(
		`Refusing to generate review drafts without ${ACCEPT_FLAG}. ` +
		"Generated translations are not a substitute for human language review.",
	);
	process.exit(2);
}

function readJson(filePath) {
	return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function chunk(values, size) {
	const chunks = [];
	for (let index = 0; index < values.length; index += size) {
		chunks.push(values.slice(index, index + size));
	}
	return chunks;
}

function translatedResponseText(payload) {
	if (Array.isArray(payload) && payload.every((segment) => typeof segment === "string")) {
		return payload.join("");
	}
	return payload[0].map((segment) => String(segment[0] ?? "")).join("");
}

async function translateBatch(strings, targetLanguage, batchNumber) {
	const markers = strings.map((_, index) => `[[L${batchNumber}_${index}]]`);
	const input = strings
		.map((value, index) => `${markers[index]} ${value.replaceAll("\n", " ")}`)
		.join("\n");
	const url = new URL("https://clients5.google.com/translate_a/t");
	url.searchParams.set("client", "dict-chrome-ex");
	url.searchParams.set("sl", "en");
	url.searchParams.set("tl", targetLanguage);
	url.searchParams.set("q", input);

	let lastError;
	for (let attempt = 1; attempt <= 4; attempt += 1) {
		try {
			const response = await fetch(url, {signal: AbortSignal.timeout(30_000)});
			if (!response.ok) {
				throw new Error(`HTTP ${response.status}`);
			}
			const translated = translatedResponseText(await response.json());
			const values = [];
			for (let index = 0; index < markers.length; index += 1) {
				const start = translated.indexOf(markers[index]);
				const next = index + 1 < markers.length
					? translated.indexOf(markers[index + 1])
					: translated.length;
				if (start < 0 || next < 0) {
					throw new Error(`Translation marker was not preserved: ${markers[index]}`);
				}
				values.push(
					translated
						.slice(start + markers[index].length, next)
						.trim()
						.replace(/\s+/gu, " "),
				);
			}
			if (values.some((value) => !value)) {
				throw new Error("Translation service returned an empty value");
			}
			return values;
		} catch (error) {
			lastError = error;
			await new Promise((resolve) => setTimeout(resolve, attempt * 750));
		}
	}
	throw lastError;
}

async function translateUniqueStrings(strings, targetLanguage) {
	const uniqueStrings = [...new Set(strings.filter(Boolean))].sort();
	const batches = chunk(uniqueStrings, batchSize);
	const translations = new Map();
	let nextBatch = 0;

	async function worker() {
		while (nextBatch < batches.length) {
			const batchNumber = nextBatch;
			nextBatch += 1;
			const sourceBatch = batches[batchNumber];
			const translatedBatch = await translateBatch(
				sourceBatch,
				targetLanguage,
				batchNumber,
			);
			for (let index = 0; index < sourceBatch.length; index += 1) {
				translations.set(sourceBatch[index], translatedBatch[index]);
			}
		}
	}

	await Promise.all(Array.from({length: concurrency}, () => worker()));
	return translations;
}

function knownReviewedTranslations(englishSource, reviewedCatalog, field) {
	const translations = new Map();
	for (const kind of ["moves", "abilities"]) {
		for (const [contentId, reviewedEntry] of Object.entries(reviewedCatalog[kind] ?? {})) {
			const sourceEntry = englishSource[kind]?.[contentId];
			const sourceValue = String(sourceEntry?.[field] ?? "").trim();
			const reviewedValue = String(reviewedEntry?.[field] ?? "").trim();
			if (sourceValue && reviewedValue) {
				translations.set(sourceValue, reviewedValue);
			}
		}
	}
	return translations;
}

function protectedGeneratedContentNames(locale) {
	const glossaryPath = path.join(terminologyDir, `${locale}.json`);
	if (!fs.existsSync(glossaryPath)) {
		return new Map();
	}
	const glossary = readJson(glossaryPath);
	const expectedPath = `res://localization/content/generated/${locale}.json`;
	const names = new Map();
	for (const [termId, term] of Object.entries(glossary.terms ?? {})) {
		for (const target of term.targets ?? []) {
			const keys = target.keys ?? [];
			if (
				target.path === expectedPath
				&& keys.length === 3
				&& ["moves", "abilities", "species"].includes(keys[0])
				&& keys[2] === "name"
			) {
				names.set(`${keys[0]}:${keys[1]}`, String(term.value));
			}
		}
		if (!term.value) {
			throw new Error(`Protected terminology entry ${termId} has no value`);
		}
	}
	return names;
}

async function generateLocale(englishSource, target) {
	const reviewedPath = path.join(projectRoot, `localization/content/${target.locale}.json`);
	const reviewedCatalog = readJson(reviewedPath);
	const reviewedNames = knownReviewedTranslations(englishSource, reviewedCatalog, "name");
	const reviewedDescriptions = knownReviewedTranslations(
		englishSource,
		reviewedCatalog,
		"shortDesc",
	);
	const protectedNames = protectedGeneratedContentNames(target.locale);
	const names = [];
	const descriptions = [];
	for (const kind of ["moves", "abilities"]) {
		for (const entry of Object.values(englishSource[kind])) {
			if (entry.name && !reviewedNames.has(entry.name)) {
				names.push(entry.name);
			}
			if (entry.shortDesc && !reviewedDescriptions.has(entry.shortDesc)) {
				descriptions.push(entry.shortDesc);
			}
		}
	}

	const [translatedNames, translatedDescriptions] = await Promise.all([
		translateUniqueStrings(names, target.translationLanguage),
		translateUniqueStrings(descriptions, target.translationLanguage),
	]);
	const generated = {
		species: englishSource.species,
		moves: {},
		abilities: {},
	};
	for (const kind of ["moves", "abilities"]) {
		for (const [contentId, sourceEntry] of Object.entries(englishSource[kind])) {
			const entry = {
				name: protectedNames.get(`${kind}:${contentId}`)
					?? reviewedNames.get(sourceEntry.name)
					?? translatedNames.get(sourceEntry.name)
					?? sourceEntry.name,
			};
			if (sourceEntry.shortDesc) {
				entry.shortDesc = reviewedDescriptions.get(sourceEntry.shortDesc)
					?? translatedDescriptions.get(sourceEntry.shortDesc)
					?? sourceEntry.shortDesc;
			}
			generated[kind][contentId] = entry;
		}
	}

	const outputPath = path.join(generatedDir, `${target.locale}.json`);
	fs.writeFileSync(outputPath, `${JSON.stringify(generated, null, 2)}\n`, "utf8");
	console.log(
		`Generated ${target.locale} review draft: ` +
		`${Object.keys(generated.moves).length} moves · ` +
		`${Object.keys(generated.abilities).length} abilities`,
	);
}

async function generateItemLocale(englishItems, target) {
	const reviewedItems = readJson(
		path.join(projectRoot, `localization/items/${target.locale}.json`),
	);
	const reviewedNames = new Map();
	const reviewedDescriptions = new Map();
	for (const [itemId, reviewedEntry] of Object.entries(reviewedItems)) {
		const sourceEntry = englishItems[itemId];
		if (!sourceEntry) {
			continue;
		}
		if (sourceEntry.name && reviewedEntry.name) {
			reviewedNames.set(sourceEntry.name, reviewedEntry.name);
		}
		if (sourceEntry.shortDesc && reviewedEntry.shortDesc) {
			reviewedDescriptions.set(sourceEntry.shortDesc, reviewedEntry.shortDesc);
		}
	}

	const names = [];
	const descriptions = [];
	for (const entry of Object.values(englishItems)) {
		if (!reviewedNames.has(entry.name)) {
			names.push(entry.name);
		}
		if (!reviewedDescriptions.has(entry.shortDesc)) {
			descriptions.push(entry.shortDesc);
		}
	}
	const [translatedNames, translatedDescriptions] = await Promise.all([
		translateUniqueStrings(names, target.translationLanguage),
		translateUniqueStrings(descriptions, target.translationLanguage),
	]);
	const generatedItems = {};
	for (const [itemId, sourceEntry] of Object.entries(englishItems)) {
		generatedItems[itemId] = {
			name: reviewedNames.get(sourceEntry.name)
				?? translatedNames.get(sourceEntry.name)
				?? sourceEntry.name,
			shortDesc: reviewedDescriptions.get(sourceEntry.shortDesc)
				?? translatedDescriptions.get(sourceEntry.shortDesc)
				?? sourceEntry.shortDesc,
		};
	}
	fs.mkdirSync(generatedItemDir, {recursive: true});
	fs.writeFileSync(
		path.join(generatedItemDir, `${target.locale}.json`),
		`${JSON.stringify(generatedItems, null, 2)}\n`,
		"utf8",
	);
	console.log(
		`Generated ${target.locale} item review draft: ` +
		`${Object.keys(generatedItems).length} items`,
	);
}

const localeFlagIndex = process.argv.indexOf(LOCALE_FLAG);
const requestedLocale = localeFlagIndex >= 0 ? String(process.argv[localeFlagIndex + 1] ?? "") : "";
const selectedTargets = requestedLocale
	? targets.filter((target) => target.locale === requestedLocale)
	: targets;
if (requestedLocale && selectedTargets.length === 0) {
	console.error(`Unknown locale for ${LOCALE_FLAG}: ${requestedLocale}`);
	process.exit(2);
}

const englishSource = readJson(englishSourcePath);
const englishItems = readJson(englishItemSourcePath);
for (const target of selectedTargets) {
	if (!process.argv.includes(ITEMS_ONLY_FLAG)) {
		await generateLocale(englishSource, target);
	}
	await generateItemLocale(englishItems, target);
}
