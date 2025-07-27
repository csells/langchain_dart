### **ModelStringParser Specification**

---

#### **Purpose**
The `ModelStringParser` class is designed to extract **provider**, **chat
model**, and **embeddings model** names from a string input. It supports
multiple formats, prioritizes clarity, and handles edge cases to ensure robust
parsing.

---

#### **Supported Formats**

| Format | Example | Parsed Output |
|-------|---------|---------------|
| **1. Provider Only** | `providerName` | `providerName`, `null`, `null` |
| **2. Provider + Chat Model (colon)** | `providerName:chatModelName` | `providerName`, `chatModelName`, `null` |
| **3. Provider + Chat Model (slash)** | `providerName/chatModelName` | `providerName`, `chatModelName`, `null` |
| **4. Provider + Chat Model (prefix)** | `providerName/chat:chatModelName` | `providerName`, `chatModelName`, `null` |
| **5. Provider + Embeddings Model** | `providerName/embeddings:embeddingsModelName` | `providerName`, `null`, `embeddingsModelName` |
| **6. Provider + Chat + Embeddings** | `providerName/chat:chatModelName/embeddings:embeddingsModelName` | `providerName`, `chatModelName`, `embeddingsModelName` |

---

#### **Parsing Rules**

1. **Segment Splitting**:
   - Input is split by `/` to separate the **provider** (first segment) and
     optional **model segments**.

2. **Provider Extraction**:
   - If the first segment contains a `:`, it is split into `providerName` and
     `chatModelName`.
   - If no `:`, the entire first segment is `providerName`.

3. **Model Segments**:
   - Remaining segments are processed in order.
   - If a segment contains `:`, it is split into a **prefix** and **model
     name**:
     - `chat:` → sets `chatModelName`
     - `embeddings:` → sets `embeddingsModelName`
     - Other prefixes → treated as `chatModelName` **only if** `chatModelName`
       is `null`
   - If a segment has no `:`, it is treated as `chatModelName` **only if**
     `chatModelName` is `null`.

4. **Overwriting**:
   - Later segments override earlier values (e.g., `provider/chat1/chat2` →
     `chatModelName = chat2`).

5. **Empty Model Names**:
   - If a model name is empty (e.g., `providerName/chat:`), the corresponding
     property is set to `null`.

6. **Unrecognized Prefixes**:
   - Segments like `other:foo` are ignored **unless** `chatModelName` is `null`.

7. **Multiple Colons**:
   - Only the **first colon** in a segment is used for parsing (e.g.,
     `provider:chat:extra` → `chatModelName = "chat:extra"`).

---

#### **Edge Case Handling**

| Input | Explanation | Output |
|-------|-------------|--------|
| `""` (empty string) | No segments → all values `null` | `null`, `null`, `null` |
| `"   "` (whitespace) | Provider is `"   "`, no models | `"   "`, `null`, `null` |
| `"providerName:"` | Empty chat model after colon → `chatModelName = null` | `"providerName"`, `null`, `null` |
| `"providerName/chatModelName/embeddingsModelName"` | Unrecognized `embeddingsModelName` segment → ignored | `"providerName"`, `"chatModelName"`, `null` |
| `"providerName//chat:chatModel"` | Empty segment skipped → `chatModelName = chatModel` | `"providerName"`, `"chatModel"`, `null` |
| `"pro/vider:gpt-3.5"` | Slash in provider name → provider is `"pro"`, chat is `"vider:gpt-3.5"` | `"pro"`, `"vider:gpt-3.5"`, `null` |
| `"providerName:chat1/chat2"` | First chat (`chat1`) overwritten by `chat2` | `"providerName"`, `"chat2"`, `null` |
| `"providerName/other:embed"` | Unrecognized prefix → treated as chat if `chatModelName` is `null` | `"providerName"`, `"other:embed"`, `null` |

---

#### **Behavior Summary**

- **Provider**:
  - Always derived from the first segment.
  - If the first segment contains a `:`, it splits into provider and chat.

- **Chat Model**:
  - Can be set by:
    - A colon in the first segment (e.g., `provider:chat`).
    - A plain segment (e.g., `provider/chat`).
    - A `chat:` prefix (e.g., `provider/chat:chat`).
    - An unrecognized prefix or plain segment if `chatModelName` is `null`.

- **Embeddings Model**:
  - Only set by `embeddings:` prefix (e.g., `provider/embeddings:embed`).

- **Null Safety**:
  - Empty model names (e.g., `provider/chat:`) → `null`.
  - Unrecognized prefixes → ignored unless chat is `null`.

- **Priority**:
  - Later segments override earlier values.

---

#### **Examples**

| Input | Provider | Chat Model | Embeddings Model |
|-------|----------|------------|------------------|
| `"providerName"` | `"providerName"` | `null` | `null` |
| `"providerName:chatModelName"` | `"providerName"` | `"chatModelName"` | `null` |
| `"providerName/chatModelName"` | `"providerName"` | `"chatModelName"` | `null` |
| `"providerName/chat:chatModelName"` | `"providerName"` | `"chatModelName"` | `null` |
| `"providerName/embeddings:embeddingsModelName"` | `"providerName"` | `null` | `"embeddingsModelName"` |
| `"providerName/chat:chatModelName/embeddings:embeddingsModelName"` | `"providerName"` | `"chatModelName"` | `"embeddingsModelName"` |
| `"providerName:chat1/chat2"` | `"providerName"` | `"chat2"` | `null` |
| `"providerName/chat:chat/embeddings:"` | `"providerName"` | `"chat"` | `null` |
| `"pro/vider:gpt-3.5"` | `"pro"` | `"vider:gpt-3.5"` | `null` |
| `"providerName/other:embed"` | `"providerName"` | `"other:embed"` | `null` |

---

#### **Design Notes**

- **Robustness**: Handles malformed or ambiguous inputs gracefully.
- **Extensibility**: Supports future prefixes (e.g., `vision:`, `audio:`) by
  ignoring unrecognized ones.
- **Clarity**: Prioritizes readability and explicit parsing logic over
  complexity.

This specification ensures consistent parsing behavior across all valid and
edge-case inputs.