# global-development-lending-analysis-and-forecasting

In today’s constrained global financing environment, development lenders need clear visibility into where funds actually land and where repayment pressure is building. This project analyzes a multi-year dataset of 3,000+ country-year records on commitments, disbursements, and repayments (including interest and fees) to measure variance vs. commitments, debt-service burden, and regional momentum (focus: 2021–2025). The work surfaces which portfolios are accelerating or stalling, and adds 2026 forecasts plus a +3% rate-shock scenario to show who is most at risk of negative net flows.

## Questions to be explored
1. Which countries experienced the largest under- or over-disbursement vs. commitments in the last fiscal year?
2. How have net flows trended over the past 5 years, and which regions show accelerating vs. decelerating funding?
3. How do interest and fees impact net flows (netFlow = gross - repayments)?
4. What’s the ratio of repayments / gross disbursements (“debt-service ratio”) by country, and which countries face the highest debt-service burden?
5. Can we forecast next fiscal year’s net flows at the country level and the regional aggregate?
6. Under a 3% upward shock in global interest rates, how would repayment schedules (and thus net flows) shift?
7. Which countries become most at risk of negative net flows under that scenario?

## Analysis Steps
1. **Step 1:** Import data (.csv files) into SQL Sever
2. **Step 2:** Exploring Data
3. **Step 3:** Profiling Data
4. **Step 4:** Cleaning Data
5. **Step 5:** Data Analysis 

## Insights
- **Variance vs. commitments:** In 2025, major borrowers under-drew—Brazil (-$4.0B), India (-$1.9B), Turkiye (-$1.91B), while over-disbursement was concentrated in Ukraine (+$4.85B), Ethiopia (+$2.77B), and Nigeria (+$0.94B), signaling uneven execution across portfolios.
- **Regional trends:** Over 2021–2025, net flows rose in Europe & Central Asia (+$8.49B) and African subregions (+$1.70B; +$1.01B), but fell in South Asia (-$4.00B), Latin America & Caribbean (-$3.78B), and East Asia & Pacific (-$2.45B), evidence of shifting regional momentum.
- **Debt-service burden:** While most countries stayed below a 25% repayment ratio, 394 country-year cases exceeded 100%, meaning repayments outpaced new disbursements and produced net outflows.
- **Forecast outlook (2026):** Trend projections point to concentrated inflows led by Ethiopia ($2.12B), Ukraine ($1.93B), and Bangladesh (~$1.51B), increasing exposure to a small set of borrowers.
- **Interest-rate sensitivity (+3%):** A modest global rate hike would reduce net flows most in India ($37M), Indonesia ($34M), and Mexico (~$27M), heightening repayment pressure and pushing some portfolios toward negative net flow.

## Recommendations
- **Close the commitment gap:** Set a ≥90% year-end utilization target and auto-flag large under-draws for a short pipeline review, use the variance vs. commitments view from this project to focus on countries like Brazil, India, and Turkiye.
- **Protect net flows from high debt service:** Maintain a DSR watchlist; act immediately when DSR ≥1.0 and review 0.40-0.99 quarterly, this targets the high-burden cases behind many of the >100% ratios and prevents negative net inflows.
- **Reallocate by momentum:** Grow allocations where execution is strong (Europe & Central Asia; African subregions) and tie releases to delivered milestones in declining regions (South Asia, LAC, EAP) to raise disbursement velocity and cut variance.
- **Plan for rate rises:** Run portfolio-wide interest-rate tests at +1% and +3% each quarter, where the hit is meaningful, starting with India, Indonesia, and Mexico, pre-plan extensions, rescheduling, fee adjustments (within policy), or simple hedges.
- **Manage concentration risk:** Set per-country exposure caps; before releasing 2026 tranches to forecast leaders (Ethiopia, Ukraine, Bangladesh, Argentina, Colombia), run a brief currency and liquidity stress check and stagger disbursements to avoid over-concentration.
