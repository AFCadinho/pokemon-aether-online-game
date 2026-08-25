#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const ACCEPT_FLAG = "--accept-machine-translation";
const batchSize = 18;
const concurrency = 1;

function argument(name, fallback = "") {
	const index = process.argv.indexOf(name);
	return index >= 0 ? String(process.argv[index + 1] ?? "") : fallback;
}

if (!process.argv.includes(ACCEPT_FLAG)) {
	console.error(`Refusing to generate a review draft without ${ACCEPT_FLAG}.`);
	process.exit(2);
}

const sourcePath = path.resolve(argument("--source"));
const outputPath = path.resolve(argument("--output"));
const targetLanguage = argument("--target", "zh-CN");
const translatedFields = new Set(
	argument("--fields")
		.split(",")
		.map((value) => value.trim())
		.filter(Boolean),
);
const localeValue = argument("--set-locale");

if (!sourcePath || !outputPath) {
	console.error("Usage: --source PATH --output PATH [--target zh-CN] [--fields name,lines] [--set-locale zh-CN]");
	process.exit(2);
}

function chunk(values, size) {
	const result = [];
	for (let index = 0; index < values.length; index += size) {
		result.push(values.slice(index, index + size));
	}
	return result;
}

function protect(value, batchNumber, valueIndex) {
	const protectedValues = [];
	const tokenPrefix = `__PA_${batchNumber}_${valueIndex}_`;
	const text = value.replace(
		/(?:\{[A-Za-z0-9_]+\}|%\d*\$?[-+0-9.*]*[A-Za-z]|\[[^\]\n]+\]|https?:\/\/\S+|\n)/gu,
		(match) => {
			const token = `${tokenPrefix}${protectedValues.length}__`;
			protectedValues.push([token, match]);
			return token;
		},
	);
	return {text, protectedValues};
}

function restore(value, protectedValues) {
	let restored = value;
	for (const [token, original] of protectedValues) {
		restored = restored.replaceAll(token, original);
	}
	return restored;
}

function translatedResponseText(payload) {
	if (Array.isArray(payload) && payload.every((segment) => typeof segment === "string")) {
		return payload.join("");
	}
	return payload[0].map((segment) => String(segment[0] ?? "")).join("");
}

async function translateBatch(strings, batchNumber) {
	const prepared = strings.map((value, index) => protect(value, batchNumber, index));
	const markers = strings.map((_, index) => `[[PA${batchNumber}_${index}]]`);
	const input = prepared
		.map((entry, index) => `${markers[index]} ${entry.text}`)
		.join("\n");
	const url = new URL("https://clients5.google.com/translate_a/t");
	url.searchParams.set("client", "dict-chrome-ex");
	url.searchParams.set("sl", "en");
	url.searchParams.set("tl", targetLanguage);
	url.searchParams.set("q", input);

	let lastError;
	for (let attempt = 1; attempt <= 5; attempt += 1) {
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
				const translatedValue = translated
					.slice(start + markers[index].length, next)
					.trim();
				const restored = restore(translatedValue, prepared[index].protectedValues);
				if (!restored || prepared[index].protectedValues.some(([token]) => restored.includes(token))) {
					throw new Error("Translation service returned an incomplete value");
				}
				values.push(restored);
			}
			await new Promise((resolve) => setTimeout(resolve, 350));
			return values;
		} catch (error) {
			lastError = error;
			await new Promise((resolve) => setTimeout(resolve, attempt * 5000));
		}
	}
	throw lastError;
}

function collectStrings(value, activeField = "", result = []) {
	if (typeof value === "string") {
		if (!translatedFields.size || translatedFields.has(activeField)) {
			result.push(value);
		}
		return result;
	}
	if (Array.isArray(value)) {
		for (const item of value) {
			collectStrings(item, activeField, result);
		}
		return result;
	}
	if (value && typeof value === "object") {
		for (const [key, item] of Object.entries(value)) {
			if (!(key === "locale" && localeValue)) {
				collectStrings(item, key, result);
			}
		}
	}
	return result;
}

function applyTranslations(value, translations, activeField = "", activeKey = "") {
	if (typeof value === "string") {
		if (activeKey === "locale" && localeValue) {
			return localeValue;
		}
		return !translatedFields.size || translatedFields.has(activeField)
			? translations.get(value) ?? value
			: value;
	}
	if (Array.isArray(value)) {
		return value.map((item) => applyTranslations(item, translations, activeField, activeKey));
	}
	if (value && typeof value === "object") {
		return Object.fromEntries(
			Object.entries(value).map(([key, item]) => [
				key,
				applyTranslations(item, translations, key, key),
			]),
		);
	}
	return value;
}

async function translateUnique(strings) {
	const unique = [...new Set(strings.filter((value) => value.trim()))].sort();
	const batches = chunk(unique, batchSize);
	const translations = new Map();
	let nextBatch = 0;
	async function worker() {
		while (nextBatch < batches.length) {
			const batchNumber = nextBatch++;
			const sourceBatch = batches[batchNumber];
			const translatedBatch = await translateBatch(sourceBatch, batchNumber);
			for (let index = 0; index < sourceBatch.length; index += 1) {
				translations.set(sourceBatch[index], translatedBatch[index]);
			}
		}
	}
	await Promise.all(Array.from({length: concurrency}, () => worker()));
	return translations;
}

const source = JSON.parse(fs.readFileSync(sourcePath, "utf8"));
const strings = collectStrings(source);
const translations = await translateUnique(strings);
const translated = applyTranslations(source, translations);
fs.mkdirSync(path.dirname(outputPath), {recursive: true});
fs.writeFileSync(outputPath, `${JSON.stringify(translated, null, 2)}\n`, "utf8");
console.log(`Generated ${outputPath}: ${translations.size} unique translated strings.`);
