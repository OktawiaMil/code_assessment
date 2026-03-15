"""
Question 4: GenAI Clinical Data Assistant

Translates natural language questions about AE data into Pandas queries.
3-stage pipeline: Schema (context) -> Parse (NLP) -> Execute (filter).

Input:  adae.csv (from pharmaversesdtm::ae)
Output: Unique subject count + matching USUBJIDs
"""

import json
from typing import Optional

import pandas as pd

# Schema describing AE columns — used by the parser to map questions to filters

AE_SCHEMA = {
    "USUBJID": {
        "type": "str",
        "description": "Unique subject identifier (e.g., 'STUDY-SITE-SUBJ')",
    },
    "AETERM": {
        "type": "str",
        "description": (
            "Reported term for the adverse event as verbatim text "
            "(e.g., 'HEADACHE', 'NAUSEA', 'DIZZINESS', 'PRURITUS')"
        ),
    },
    "AEDECOD": {
        "type": "str",
        "description": (
            "Dictionary-derived adverse event term (MedDRA preferred term), "
            "standardized version of AETERM"
        ),
    },
    "AESOC": {
        "type": "str",
        "description": (
            "Primary system organ class for the AE "
            "(e.g., 'CARDIAC DISORDERS', 'SKIN AND SUBCUTANEOUS TISSUE DISORDERS', "
            "'NERVOUS SYSTEM DISORDERS', 'GASTROINTESTINAL DISORDERS')"
        ),
    },
    "AESEV": {
        "type": "str",
        "description": (
            "Severity/intensity of the adverse event. "
            "Values: 'MILD', 'MODERATE', 'SEVERE'"
        ),
    },
    "AESER": {
        "type": "str",
        "description": "Is the AE serious? Values: 'Y' (yes), 'N' (no)",
    },
    "AEREL": {
        "type": "str",
        "description": (
            "Causality - relationship of AE to study drug. "
            "Values: 'RELATED', 'NOT RELATED', 'POSSIBLY RELATED'"
        ),
    },
    "AEACN": {
        "type": "str",
        "description": (
            "Action taken with study treatment. "
            "Values: 'DOSE NOT CHANGED', 'DRUG WITHDRAWN', 'DOSE REDUCED', etc."
        ),
    },
    "AEOUT": {
        "type": "str",
        "description": (
            "Outcome of the adverse event. "
            "Values: 'RECOVERED/RESOLVED', 'NOT RECOVERED/NOT RESOLVED', "
            "'RECOVERING/RESOLVING', 'FATAL'"
        ),
    },
    "AESTDTC": {
        "type": "str",
        "description": "Start date/time of adverse event (ISO 8601 format)",
    },
    "AEENDTC": {
        "type": "str",
        "description": "End date/time of adverse event (ISO 8601 format)",
    },
}


class ClinicalTrialDataAgent:
    """Translates natural language AE questions into Pandas filters.

    Pipeline: schema context -> keyword-based NLP parsing -> Pandas execution.

    In a production setting this parser would be replaced by an LLM call
    (e.g. GPT-4) that receives the schema as context and returns structured
    JSON. The keyword-based approach here demonstrates the same pipeline
    structure without requiring API access.
    """

    def __init__(
        self,
        df: pd.DataFrame,
        schema: dict = AE_SCHEMA,
    ):
        self.df = df
        self.schema = schema

    # --- Stage 1: Build schema context for the parser ---

    def _build_schema_context(self) -> str:
        """Format the schema into a readable description (would be the LLM prompt)."""
        return "\n".join(
            f"  - {col}: {info['description']} (type: {info['type']})"
            for col, info in self.schema.items()
        )

    # --- Stage 2: Parse question into structured filter ---

    def _parse_question(self, question: str) -> dict:
        """Extract target_column and filter_value from a natural language question.

        Uses keyword matching against the schema to route the question to the
        right column. Returns a dict like {"target_column": "AESEV", "filter_value": "MODERATE"}.
        """
        q = question.lower()

        # Severity -> AESEV
        for severity in ["severe", "mild", "moderate"]:
            if severity in q:
                return {
                    "target_column": "AESEV",
                    "filter_value": severity.upper(),
                }

        # Serious -> AESER
        if "serious" in q:
            return {"target_column": "AESER", "filter_value": "Y"}

        # Body system -> AESOC
        soc_keywords = {
            "cardiac": "CARDIAC DISORDERS",
            "heart": "CARDIAC DISORDERS",
            "skin": "SKIN AND SUBCUTANEOUS TISSUE DISORDERS",
            "dermatol": "SKIN AND SUBCUTANEOUS TISSUE DISORDERS",
            "nervous": "NERVOUS SYSTEM DISORDERS",
            "neurolog": "NERVOUS SYSTEM DISORDERS",
            "gastro": "GASTROINTESTINAL DISORDERS",
            "digestive": "GASTROINTESTINAL DISORDERS",
            "respiratory": "RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS",
            "vascular": "VASCULAR DISORDERS",
            "musculoskeletal": "MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS",
            "infection": "INFECTIONS AND INFESTATIONS",
            "psychiatric": "PSYCHIATRIC DISORDERS",
            "eye": "EYE DISORDERS",
            "renal": "RENAL AND URINARY DISORDERS",
            "general disorder": "GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS",
            "application site": "GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS",
        }
        for keyword, soc_value in soc_keywords.items():
            if keyword in q:
                return {"target_column": "AESOC", "filter_value": soc_value}

        # Outcome -> AEOUT
        outcome_keywords = {
            "resolved": "RECOVERED/RESOLVED",
            "recovered": "RECOVERED/RESOLVED",
            "fatal": "FATAL",
            "not resolved": "NOT RECOVERED/NOT RESOLVED",
            "recovering": "RECOVERING/RESOLVING",
        }
        for keyword, out_value in outcome_keywords.items():
            if keyword in q:
                return {"target_column": "AEOUT", "filter_value": out_value}

        # Relatedness -> AEREL
        if "related" in q and "not related" not in q:
            return {"target_column": "AEREL", "filter_value": "RELATED"}
        if "not related" in q:
            return {"target_column": "AEREL", "filter_value": "NOT RELATED"}

        # Drug action -> AEACN
        if "withdrawn" in q or "drug withdrawal" in q:
            return {"target_column": "AEACN", "filter_value": "DRUG WITHDRAWN"}

        # Default: try to match a specific AE term
        condition = self._extract_condition_term(q)
        if condition:
            return {"target_column": "AETERM", "filter_value": condition.upper()}

        # Nothing matched
        return {
            "target_column": "AETERM",
            "filter_value": "UNKNOWN",
        }

    def _extract_condition_term(self, question: str) -> str:
        """Try to find a known AE term in the question text."""
        ae_terms = [
            "headache", "nausea", "dizziness", "fatigue", "vomiting",
            "diarrhoea", "pruritus", "rash", "erythema", "pain",
            "insomnia", "cough", "pyrexia", "arthralgia", "constipation",
            "application site pruritus", "application site erythema",
            "application site dermatitis", "application site irritation",
            "sinus bradycardia", "atrial fibrillation",
        ]
        # Longest first so multi-word terms match before single words
        for term in sorted(ae_terms, key=len, reverse=True):
            if term in question:
                return term
        return ""

    # --- Stage 3: Execute filter ---

    def _execute_query(self, parsed: dict) -> dict:
        """Apply the parsed filter to the dataframe and return matching subjects."""
        if "target_column" not in parsed or "filter_value" not in parsed:
            return {
                "count": 0,
                "subject_ids": [],
                "filter_applied": parsed,
                "error": f"Parser returned unexpected keys: {list(parsed.keys())}",
            }

        col = parsed["target_column"]
        val = parsed["filter_value"]

        if col not in self.df.columns:
            return {
                "count": 0,
                "subject_ids": [],
                "filter_applied": parsed,
                "error": f"Column '{col}' not found in dataset. "
                         f"Available: {list(self.df.columns)}",
            }

        # AESOC uses contains (partial match for body system names), rest use exact
        if col == "AESOC":
            mask = self.df[col].str.upper().str.contains(val.upper(), na=False)
        else:
            mask = self.df[col].str.upper() == val.upper()

        filtered = self.df[mask]
        unique_subjects = filtered["USUBJID"].unique().tolist()

        return {
            "count": len(unique_subjects),
            "subject_ids": unique_subjects,
            "filter_applied": parsed,
        }

    # --- Public API ---

    def query(self, question: str) -> dict:
        """Translate a natural language question into a filter and execute it."""
        parsed = self._parse_question(question)
        return self._execute_query(parsed)

    def query_verbose(self, question: str) -> dict:
        """Like query() but prints each stage for debugging."""
        print(f"\n{'='*60}")
        print(f"Question: {question}")
        print(f"{'='*60}")

        # Stage 1: schema context
        schema_ctx = self._build_schema_context()
        print(f"\n[Stage 1 - SCHEMA] {len(self.schema)} columns available")

        # Stage 2: parse
        parsed = self._parse_question(question)
        print(f"[Stage 2 - PARSE] Extracted: {json.dumps(parsed)}")

        # Stage 3: execute
        result = self._execute_query(parsed)
        print(f"[Stage 3 - EXECUTE] Found {result['count']} unique subjects")
        if result["count"] > 0:
            preview = result["subject_ids"][:5]
            print(f"  Sample IDs: {preview}")
            if result["count"] > 5:
                print(f"  ... and {result['count'] - 5} more")

        return result
