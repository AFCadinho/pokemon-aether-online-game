#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const projectRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const backendSpeciesDir = path.resolve(
	process.argv[2] ?? path.join(projectRoot, "../pokemon-aether-backend/pokemon-data/data/species"),
);
const outputPath = path.join(projectRoot, "localization/content/generated/en.json");
const backendItemsDir = path.resolve(backendSpeciesDir, "..", "items");
const itemOutputPath = path.join(projectRoot, "localization/items/generated/en.json");

function readJson(filePath) {
	return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function presentationEntry(value) {
	const entry = {name: String(value.name ?? value.id ?? "").trim()};
	const shortDescription = String(value.shortDesc ?? "").trim();
	if (shortDescription) {
		entry.shortDesc = shortDescription;
	}
	return entry;
}

function sortedObject(entries) {
	return Object.fromEntries(
		Object.entries(entries).sort(([left], [right]) => left.localeCompare(right)),
	);
}

function loadSpecies() {
	if (!fs.existsSync(backendSpeciesDir)) {
		throw new Error(`Species source directory does not exist: ${backendSpeciesDir}`);
	}

	const species = {};
	for (const fileName of fs.readdirSync(backendSpeciesDir).sort()) {
		if (!fileName.endsWith(".json")) {
			continue;
		}
		const source = readJson(path.join(backendSpeciesDir, fileName));
		const speciesId = String(source.species_id ?? "").trim();
		const name = String(source.name ?? "").trim();
		if (!speciesId || !name) {
			throw new Error(`Missing species_id or name in ${fileName}`);
		}
		if (species[speciesId]) {
			throw new Error(`Duplicate species ID: ${speciesId}`);
		}
		species[speciesId] = {name};
	}
	return sortedObject(species);
}

function loadIndex(relativePath) {
	const source = readJson(path.join(projectRoot, relativePath));
	return sortedObject(
		Object.fromEntries(
			Object.entries(source).map(([contentId, value]) => [
				contentId,
				presentationEntry(value),
			]),
		),
	);
}

function loadItems() {
	if (!fs.existsSync(backendItemsDir)) {
		throw new Error(`Item source directory does not exist: ${backendItemsDir}`);
	}

	const items = {};
	for (const fileName of fs.readdirSync(backendItemsDir).sort()) {
		if (!fileName.endsWith(".json")) {
			continue;
		}
		const sourceFile = readJson(path.join(backendItemsDir, fileName));
		for (const value of Object.values(sourceFile)) {
			if (!value || typeof value !== "object" || Array.isArray(value)) {
				continue;
			}
			const itemId = String(value.id ?? "").trim();
			const name = String(value.name ?? "").trim();
			const shortDescription = [
				value.short_desc,
				value.shortDesc,
				value.desc,
				value.description,
				value.flavor_text,
			]
				.map((candidate) => String(candidate ?? "").trim())
				.find(Boolean) ?? "";
			if (!itemId || !name || !shortDescription) {
				throw new Error(`Incomplete item presentation in ${fileName}: ${itemId}`);
			}
			if (items[itemId]) {
				throw new Error(`Duplicate item ID: ${itemId}`);
			}
			items[itemId] = {name, shortDesc: shortDescription};
		}
	}
	return sortedObject(items);
}

const generatedCatalog = {
	species: loadSpecies(),
	moves: loadIndex("data/move_summary_index.json"),
	abilities: loadIndex("data/ability_summary_index.json"),
};

fs.mkdirSync(path.dirname(outputPath), {recursive: true});
fs.writeFileSync(outputPath, `${JSON.stringify(generatedCatalog, null, 2)}\n`, "utf8");
const generatedItems = loadItems();
fs.mkdirSync(path.dirname(itemOutputPath), {recursive: true});
fs.writeFileSync(itemOutputPath, `${JSON.stringify(generatedItems, null, 2)}\n`, "utf8");

console.log(
	[
		`Generated ${outputPath}`,
		`${Object.keys(generatedCatalog.species).length} species`,
		`${Object.keys(generatedCatalog.moves).length} moves`,
		`${Object.keys(generatedCatalog.abilities).length} abilities`,
		`${Object.keys(generatedItems).length} items`,
	].join(" · "),
);
