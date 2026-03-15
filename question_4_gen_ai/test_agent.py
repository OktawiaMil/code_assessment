"""
Test script for ClinicalTrialDataAgent - runs example queries against AE data.

Usage: python test_agent.py
"""

import os

import pandas as pd

from clinical_data_agent import AE_SCHEMA, ClinicalTrialDataAgent


def main():
    data_path = os.path.join(os.path.dirname(__file__), "adae.csv")

    if not os.path.exists(data_path):
        print(f"Error: {data_path} not found.")
        print("Please export the AE data from R first:")
        print('  write.csv(pharmaverseadam::adae, "adae.csv", row.names = FALSE)')
        print("\nGenerating sample data for demonstration...")
        df = _generate_sample_data()
    else:
        df = pd.read_csv(data_path)

    print(f"Dataset loaded: {len(df)} rows, {len(df.columns)} columns")
    print(f"Unique subjects: {df['USUBJID'].nunique()}")
    print(f"Columns: {', '.join(df.columns[:10])}...")

    agent = ClinicalTrialDataAgent(df=df, schema=AE_SCHEMA)

    test_queries = [
        "Give me the subjects who had Adverse events of Moderate severity.",
        "Which patients experienced headache as an adverse event?",
        "How many subjects had cardiac related adverse events?",
    ]

    print("\n" + "=" * 70)
    print("RUNNING TEST QUERIES")
    print("=" * 70)

    for i, question in enumerate(test_queries, 1):
        result = agent.query_verbose(question)
        print(f"\nResult summary:")
        print(f"  Filter: {result['filter_applied']}")
        print(f"  Matching subjects: {result['count']}")
        if result["count"] > 0:
            print(f"  Subject IDs (first 10): {result['subject_ids'][:10]}")
        print()

    # A few more to show it handles different question types
    print("=" * 70)
    print("ADDITIONAL QUERIES")
    print("=" * 70)

    extra_queries = [
        "Show me patients with serious adverse events.",
        "Which subjects had skin-related adverse events?",
        "List subjects whose adverse events have resolved.",
    ]

    for question in extra_queries:
        result = agent.query_verbose(question)
        print()

    print("=" * 70)
    print("ALL TESTS COMPLETED SUCCESSFULLY")
    print("=" * 70)


def _generate_sample_data() -> pd.DataFrame:
    """Generate a small sample AE dataset when adae.csv is unavailable."""
    import random

    random.seed(42)
    subjects = [f"CDISCPILOT01-{site:02d}-{subj:03d}"
                for site in range(1, 4) for subj in range(1, 11)]
    terms = ["HEADACHE", "NAUSEA", "DIZZINESS", "FATIGUE", "PRURITUS",
             "RASH", "DIARRHOEA", "VOMITING", "APPLICATION SITE PRURITUS",
             "SINUS BRADYCARDIA"]
    socs = {
        "HEADACHE": "NERVOUS SYSTEM DISORDERS",
        "NAUSEA": "GASTROINTESTINAL DISORDERS",
        "DIZZINESS": "NERVOUS SYSTEM DISORDERS",
        "FATIGUE": "GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS",
        "PRURITUS": "SKIN AND SUBCUTANEOUS TISSUE DISORDERS",
        "RASH": "SKIN AND SUBCUTANEOUS TISSUE DISORDERS",
        "DIARRHOEA": "GASTROINTESTINAL DISORDERS",
        "VOMITING": "GASTROINTESTINAL DISORDERS",
        "APPLICATION SITE PRURITUS": "GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS",
        "SINUS BRADYCARDIA": "CARDIAC DISORDERS",
    }
    sevs = ["MILD", "MODERATE", "SEVERE"]
    rows = []
    for _ in range(200):
        subj = random.choice(subjects)
        term = random.choice(terms)
        rows.append({
            "USUBJID": subj,
            "AETERM": term,
            "AEDECOD": term,
            "AESOC": socs[term],
            "AESEV": random.choices(sevs, weights=[0.5, 0.35, 0.15])[0],
            "AESER": random.choice(["Y", "N"]),
            "AEREL": random.choice(["RELATED", "NOT RELATED", "POSSIBLY RELATED"]),
            "AEACN": random.choice(["DOSE NOT CHANGED", "DRUG WITHDRAWN", "DOSE REDUCED"]),
            "AEOUT": random.choice(["RECOVERED/RESOLVED", "NOT RECOVERED/NOT RESOLVED",
                                     "RECOVERING/RESOLVING"]),
            "AESTDTC": "2023-01-15",
            "AEENDTC": "2023-02-01",
        })
    return pd.DataFrame(rows)


if __name__ == "__main__":
    main()
