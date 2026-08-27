#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import {fileURLToPath} from "node:url";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const glossaryPath = path.join(projectRoot, "localization/terminology/zh_CN.json");
const protectedCatalogs = [
	"localization/zh_CN.json",
	"localization/content/zh_CN.json",
	"localization/content/generated/zh_CN.json",
	"localization/items/zh_CN.json",
	"localization/items/generated/zh_CN.json",
];
const allowedStatuses = new Set(["official", "official_legacy", "project_approved"]);

function fail(message) {
	console.error(`Chinese terminology check failed: ${message}`);
	process.exitCode = 1;
}

function readJson(relativePath) {
	return JSON.parse(fs.readFileSync(path.join(projectRoot, relativePath), "utf8"));
}

function catalogPath(resourcePath) {
	return String(resourcePath).replace(/^res:\/\//u, "");
}

function resolveKeys(value, keys) {
	let resolved = value;
	for (const key of keys) {
		if (!resolved || typeof resolved !== "object" || !(key in resolved)) {
			return undefined;
		}
		resolved = resolved[key];
	}
	return resolved;
}

function containsText(value, needle) {
	if (typeof value === "string") {
		return value.includes(needle);
	}
	if (Array.isArray(value)) {
		return value.some((child) => containsText(child, needle));
	}
	if (value && typeof value === "object") {
		return Object.values(value).some((child) => containsText(child, needle));
	}
	return false;
}

const glossary = readJson("localization/terminology/zh_CN.json");
if (glossary.schemaVersion !== 1 || glossary.locale !== "zh_CN") {
	fail("unsupported glossary schema or locale");
}
if (glossary.policy?.unreviewedLiteralTranslationsAllowed !== false) {
	fail("unreviewed literal translations must remain disabled");
}

const catalogs = new Map(protectedCatalogs.map((relativePath) => [relativePath, readJson(relativePath)]));
const sources = glossary.sources ?? {};
for (const [sourceId, source] of Object.entries(sources)) {
	if (!String(source.label ?? "").trim() || !String(source.url ?? "").startsWith("https://")) {
		fail(`source ${sourceId} must have a label and HTTPS URL`);
	}
}

for (const [termId, term] of Object.entries(glossary.terms ?? {})) {
	if (!String(term.value ?? "").trim()) {
		fail(`term ${termId} has no value`);
	}
	if (!allowedStatuses.has(String(term.status ?? ""))) {
		fail(`term ${termId} has an unapproved review status`);
	}
	if (!Array.isArray(term.sourceIds) || term.sourceIds.length === 0) {
		fail(`term ${termId} does not cite a source`);
	}
	for (const sourceId of term.sourceIds ?? []) {
		if (!(sourceId in sources)) {
			fail(`term ${termId} cites unknown source ${sourceId}`);
		}
	}
	if ((termId.startsWith("badge.") || termId.startsWith("move.")) && !term.targets?.length) {
		fail(`term ${termId} does not protect a catalog target`);
	}
	for (const target of term.targets ?? []) {
		const relativePath = catalogPath(target.path);
		if (!catalogs.has(relativePath)) {
			fail(`term ${termId} targets unprotected catalog ${relativePath}`);
			continue;
		}
		if (resolveKeys(catalogs.get(relativePath), target.keys ?? []) !== term.value) {
			fail(`term ${termId} does not match ${relativePath}:${(target.keys ?? []).join(".")}`);
		}
	}
}

for (const literal of Object.keys(glossary.forbiddenLiteralTranslations ?? {})) {
	for (const [relativePath, catalog] of catalogs) {
		if (containsText(catalog, literal)) {
			fail(`${relativePath} contains forbidden literal translation ${literal}`);
		}
	}
}

if (!process.exitCode) {
	console.log(`Chinese terminology check passed: ${Object.keys(glossary.terms ?? {}).length} protected terms.`);
}
