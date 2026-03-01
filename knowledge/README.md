# perch_care Knowledge Base

## Purpose

This directory contains the knowledge base documents for the **perch_care** avian health management application. These documents serve as the source data for the app's **Retrieval-Augmented Generation (RAG) system**, which uses **pgvector** (PostgreSQL vector extension) with OpenAI's **text-embedding-3-small** embedding model to provide accurate, contextually relevant information to users through the AI-powered health check feature.

Documents are chunked, embedded, and stored as vectors in PostgreSQL, enabling semantic search to retrieve the most relevant knowledge when users ask questions about their pet birds' health, nutrition, behavior, and species-specific care.

---

## Knowledge Categories

The knowledge base is organized into four major categories:

### 1. Diseases (~100 documents)
**Path:** `diseases/`

Comprehensive veterinary information about avian diseases and health conditions, organized by body system and type.

| Subcategory | Description |
|-------------|-------------|
| `infectious/` | Bacterial, viral, fungal, and parasitic infections (e.g., Psittacosis, PBFD, Aspergillosis) |
| `nutritional/` | Nutrition-related disorders (e.g., Vitamin A deficiency, metabolic bone disease) |
| `respiratory/` | Respiratory system diseases and conditions |
| `gastrointestinal/` | Digestive system disorders (e.g., PDD, crop stasis) |
| `reproductive/` | Reproductive health issues (e.g., egg binding, chronic egg laying) |
| `musculoskeletal/` | Bone and joint conditions (e.g., fractures, bumblefoot) |
| `dermatological/` | Skin and feather conditions (e.g., feather destructive behavior, mites) |
| `neurological/` | Nervous system disorders |
| `organ-diseases/` | Organ-specific diseases (e.g., liver disease, kidney disease, atherosclerosis) |
| `toxicology/` | Toxic substances and poisoning (e.g., heavy metal toxicity, Teflon/PTFE) |
| `emergency/` | Emergency conditions requiring immediate veterinary attention |
| `general-care/` | Preventive health care, wellness exams, quarantine protocols |

### 2. Nutrition (~50 documents)
**Path:** `nutrition/`

Detailed nutritional guidance for companion birds covering dietary fundamentals, supplements, and species-specific needs.

| Subcategory | Description |
|-------------|-------------|
| `fundamentals/` | Core nutritional concepts (e.g., pellet vs. seed diets, macronutrients) |
| `vitamins-supplements/` | Vitamin, mineral, and supplement information |
| `life-stage/` | Nutritional needs by life stage (chick, juvenile, adult, senior, breeding) |
| `species-specific/` | Diet recommendations tailored to specific species or groups |
| `toxic-foods/` | Foods dangerous or toxic to birds (e.g., avocado, chocolate, caffeine) |
| `feeding-management/` | Practical feeding guidance (e.g., food preparation, portion control, foraging) |

### 3. Species (~35 documents)
**Path:** `species/`

Species profiles covering the most commonly kept companion bird species, organized by size category.

| Subcategory | Description |
|-------------|-------------|
| `small/` | Small parrots under 100g (e.g., budgerigar, cockatiel, lovebirds, parrotlet) |
| `medium/` | Medium parrots 100--400g (e.g., conures, caiques, Indian ringneck, Senegal parrot) |
| `large/` | Large parrots 400g+ (e.g., African Grey, Amazon parrots, Eclectus) |
| `cockatoos/` | Cockatoo species (e.g., Sulphur-crested, Umbrella, Moluccan, Galah) |
| `macaws/` | Macaw species (e.g., Blue-and-Gold, Scarlet, Green-winged, Hahn's) |

See [`species/_index.md`](species/_index.md) for a complete listing of all 35 species with links.

### 4. Behavior (~50 documents)
**Path:** `behavior/`

Information on avian behavior, psychology, training, and environmental enrichment.

| Subcategory | Description |
|-------------|-------------|
| `normal/` | Normal avian behaviors and body language interpretation |
| `problematic/` | Problem behaviors (e.g., biting, screaming, feather plucking, aggression) |
| `training/` | Training techniques and methods (e.g., positive reinforcement, target training) |
| `socialization/` | Socialization guidance for birds with people and other animals |
| `enrichment-environment/` | Environmental enrichment, cage setup, and stimulation strategies |
| `stress-mental-health/` | Stress indicators, mental health, and emotional well-being |

---

## Document Format

All knowledge documents are written in **Markdown** format and follow standardized templates specific to each category. This consistency ensures reliable chunking and embedding during the RAG pipeline ingestion process.

### Species Document Template
Each species document includes the following sections:
- **Overview** -- Brief species introduction
- **Basic Information** -- Family, origin, size, weight, lifespan
- **Appearance** -- Physical description and color mutations
- **Temperament & Personality** -- Behavioral traits, noise level, talking ability
- **Care Requirements** -- Housing, diet, exercise, and enrichment needs
- **Common Health Issues** -- Species-specific health concerns
- **Breeding Information** -- Basic reproductive information
- **References** -- Cited sources with URLs

### Disease Document Template
Each disease document includes:
- **Overview** -- Brief condition description
- **Affected Species** -- Which species are most susceptible
- **Causes / Etiology** -- Underlying causes
- **Symptoms / Clinical Signs** -- Observable signs
- **Diagnosis** -- Diagnostic methods
- **Treatment** -- Treatment approaches
- **Prevention** -- Preventive measures
- **Prognosis** -- Expected outcomes
- **References** -- Cited sources with URLs

---

## Content Standards

- All content is based on **real veterinary and avian care sources**, including peer-reviewed literature, veterinary hospital resources, and established aviculture references.
- Every document includes a **References section** with URLs to source material from trusted providers such as:
  - VCA Hospitals (vcahospitals.com)
  - Lafeber Company (lafeber.com)
  - Merck Veterinary Manual (merckvetmanual.com)
  - The Spruce Pets (thesprucepets.com)
  - PetMD (petmd.com)
  - Beauty of Birds (beautyofbirds.com)
  - Association of Avian Veterinarians (aav.org)
- No fabricated medical or veterinary information is included in any document.
- Documents are written in English for consistency in the embedding pipeline.

---

## RAG Pipeline Integration

```
Knowledge Base (Markdown files)
        |
        v
  Chunking (split by sections/headers)
        |
        v
  Embedding (text-embedding-3-small)
        |
        v
  Storage (PostgreSQL + pgvector)
        |
        v
  Retrieval (semantic similarity search)
        |
        v
  Generation (LLM response with retrieved context)
```

Documents are processed as follows:
1. Markdown files are parsed and split into chunks by section headers (H2/H3 level).
2. Each chunk is embedded using OpenAI's `text-embedding-3-small` model (1536-dimensional vectors).
3. Embeddings are stored in PostgreSQL using the `pgvector` extension alongside metadata (category, species, source file).
4. At query time, the user's question is embedded and compared against stored vectors using cosine similarity.
5. The top-k most relevant chunks are retrieved and provided as context to the LLM for answer generation.
