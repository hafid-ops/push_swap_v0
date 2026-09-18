#!/bin/bash

PS="./push_swap"
CHECKER="./checker"
PROVIDED_CHECKER="./checker_linux"

PASS=0
FAIL=0
WARN=0

green="\033[32m"
red="\033[31m"
yellow="\033[33m"
cyan="\033[36m"
reset="\033[0m"

pass()
{
	echo -e "${green}[PASS]${reset} $1"
	PASS=$((PASS + 1))
}

fail()
{
	echo -e "${red}[FAIL]${reset} $1"
	FAIL=$((FAIL + 1))
}

warn()
{
	echo -e "${yellow}[WARN]${reset} $1"
	WARN=$((WARN + 1))
}

title()
{
	echo
	echo -e "${cyan}===== $1 =====${reset}"
}

cleanup()
{
	rm -f \
		error.tmp err.tmp out.tmp \
		operations.tmp benchmark.tmp \
		valgrind.tmp make2.tmp
}

trap cleanup EXIT

# ==================================================
title "1. BUILD MANDATORY"
# ==================================================

make fclean >/dev/null 2>&1

if make >/dev/null 2>&1; then
	pass "make"
else
	fail "make"
	exit 1
fi

if [ -x "$PS" ]; then
	pass "push_swap executable exists"
else
	fail "push_swap executable missing"
	exit 1
fi

for rule in all clean fclean re; do
	if grep -Eq "^${rule}[[:space:]]*:" Makefile; then
		pass "Makefile contains $rule"
	else
		fail "Makefile missing $rule"
	fi
done

if grep -q -- "-Wall" Makefile &&
	grep -q -- "-Wextra" Makefile &&
	grep -q -- "-Werror" Makefile; then
	pass "Makefile uses -Wall -Wextra -Werror"
else
	fail "Makefile missing required compiler flags"
fi

make >/dev/null 2>&1
make >make2.tmp 2>&1

if grep -Eq "(cc|gcc|clang).*(-c| -o )" make2.tmp; then
	warn "possible unnecessary relinking detected"
else
	pass "second make does not appear to relink"
fi

rm -f make2.tmp

# ==================================================
title "2. BUILD BONUS"
# ==================================================

if make bonus >/dev/null 2>&1; then
	pass "make bonus"
else
	warn "make bonus failed"
fi

if [ -x "$CHECKER" ]; then
	pass "checker executable exists"
else
	warn "checker executable missing"
fi

# # ==================================================
# title "3. README / GROUP REQUIREMENTS"
# # ==================================================

# if [ -f README.md ]; then
# 	pass "README.md exists"
# else
# 	fail "README.md missing"
# fi

# if [ -f README.md ]; then

# 	FIRST_LINE=$(head -n 1 README.md)

# 	if echo "$FIRST_LINE" | \
# 	grep -Eq '^\*This project has been created as part of the 42 curriculum by .*\.\*$'
# then
# 	pass "README first line format"
# else
# 	fail "README first line format"
# fi

# 	for section in \
# 		"Description" \
# 		"Instructions" \
# 		"Resources"
# 	do
# 		if grep -qi "$section" README.md; then
# 			pass "README contains $section"
# 		else
# 			fail "README missing $section"
# 		fi
# 	done

# 	if grep -qi "AI" README.md; then
# 		pass "README documents AI usage"
# 	else
# 		fail "README missing AI usage"
# 	fi

# 	if grep -qi "Simple" README.md &&
# 		grep -qi "Medium" README.md &&
# 		grep -qi "Complex" README.md &&
# 		grep -qi "Adaptive" README.md; then
# 		pass "README documents all four strategies"
# 	else
# 		fail "README strategy documentation incomplete"
# 	fi

# 	if grep -Eqi "contribution|contributor" README.md; then
# 		pass "README contains contribution section"
# 	else
# 		fail "README missing learner contributions"
# 	fi
# fi

# ==================================================
title "4. MANDATORY BASIC BEHAVIOR"
# ==================================================

OUTPUT=$($PS 2>&1)

if [ -z "$OUTPUT" ]; then
	pass "push_swap no args -> no output"
else
	fail "push_swap no args produced output"
fi

# ==================================================
title "5. ERROR MANAGEMENT"
# ==================================================

test_error()
{
	local label="$1"
	shift

	"$PS" "$@" >/dev/null 2>error.tmp

	if grep -qx "Error" error.tmp; then
		pass "$label"
	else
		fail "$label"
	fi
}

test_error "reject duplicate" 1 2 2
test_error "reject non numeric" 1 abc 3
test_error "reject decimal" 1 2.5 3
test_error "reject INT_MAX overflow" 2147483648
test_error "reject INT_MIN overflow" -2147483649
test_error "reject unknown flag" --banana 3 2 1
test_error "reject plus only" "+"
test_error "reject minus only" "-"
test_error "reject huge integer" \
	999999999999999999999999999999999
test_error "reject empty argument" ""

rm -f error.tmp

# ==================================================
title "6. STRATEGY SELECTION BASIC TESTS"
# ==================================================

TEST_CHECKER="$CHECKER"

if [ -x "$PROVIDED_CHECKER" ]; then
	TEST_CHECKER="$PROVIDED_CHECKER"
elif [ ! -x "$CHECKER" ]; then
	TEST_CHECKER=""
fi

if [ -n "$TEST_CHECKER" ]; then

	for strategy in simple medium complex adaptive; do

		ARG="5 4 3 2 1"

		RESULT=$($PS --$strategy $ARG | $TEST_CHECKER $ARG)

		if [ "$RESULT" = "OK" ]; then
			pass "--$strategy sorts 5 4 3 2 1"
		else
			fail "--$strategy result: $RESULT"
		fi

	done

	ARG="5 4 3 2 1"
	RESULT=$($PS $ARG | $TEST_CHECKER $ARG)

	if [ "$RESULT" = "OK" ]; then
		pass "default strategy sorts correctly"
	else
		fail "default strategy failed"
	fi
else
	warn "no checker available for strategy correctness"
fi

# ==================================================
title "7. IDENTITY TESTS - ALREADY SORTED"
# ==================================================

identity_tests=(
	"42"
	"2 3"
	"0 1 2 3"
	"0 1 2 3 4 5 6 7 8 9"
)

for ARG in "${identity_tests[@]}"; do

	OUTPUT=$($PS $ARG)

	if [ -z "$OUTPUT" ]; then
		pass "0 operations: $ARG"
	else
		COUNT=$(echo "$OUTPUT" | wc -l)
		fail "sorted input emitted $COUNT ops: $ARG"
	fi

done

# ==================================================
title "8. SMALL INPUTS - 3 NUMBERS"
# ==================================================

small3_tests=(
	"2 1 0"
	"0 2 1"
	"1 0 2"
	"2 0 1"
	"1 2 0"
	"0 1 2"
)

if [ -n "$TEST_CHECKER" ]; then

	for ARG in "${small3_tests[@]}"; do

		COUNT=$($PS $ARG | wc -l)
		RESULT=$($PS $ARG | $TEST_CHECKER $ARG)

		if [ "$RESULT" != "OK" ]; then
			fail "3 elements incorrect: $ARG"
		elif [ "$COUNT" -le 3 ]; then
			pass "3 elements GOOD: $ARG -> $COUNT ops"
		elif [ "$COUNT" -le 5 ]; then
			pass "3 elements ACCEPTABLE: $ARG -> $COUNT ops"
		else
			fail "3 elements too many ops: $ARG -> $COUNT"
		fi

	done
fi

# ==================================================
title "9. MEDIUM INPUTS - 5 NUMBERS"
# ==================================================

small5_tests=(
	"1 5 2 4 3"
	"5 1 4 2 3"
	"3 5 1 4 2"
	"5 4 3 2 1"
)

if [ -n "$TEST_CHECKER" ]; then

	for ARG in "${small5_tests[@]}"; do

		COUNT=$($PS $ARG | wc -l)
		RESULT=$($PS $ARG | $TEST_CHECKER $ARG)

		if [ "$RESULT" != "OK" ]; then
			fail "5 elements incorrect: $ARG"
		elif [ "$COUNT" -le 12 ]; then
			pass "5 elements GOOD: $ARG -> $COUNT ops"
		elif [ "$COUNT" -le 15 ]; then
			pass "5 elements ACCEPTABLE: $ARG -> $COUNT ops"
		else
			fail "5 elements above evaluator target: $ARG -> $COUNT"
		fi

	done
fi

# ==================================================
title "10. BENCHMARK MODE"
# ==================================================

$PS --bench --simple 5 4 3 2 1 \
	>operations.tmp 2>benchmark.tmp

for field in \
	"Disorder:" \
	"Strategy:" \
	"Complexity:" \
	"Total operations:" \
	"sa:" \
	"sb:" \
	"ss:" \
	"pa:" \
	"pb:" \
	"ra:" \
	"rb:" \
	"rr:" \
	"rra:" \
	"rrb:" \
	"rrr:"
do

	if grep -q "$field" benchmark.tmp; then
		pass "benchmark contains $field"
	else
		fail "benchmark missing $field"
	fi

done

if grep -q "Disorder:" operations.tmp; then
	fail "benchmark leaked into stdout"
else
	pass "benchmark stays on stderr"
fi

rm -f operations.tmp benchmark.tmp

# ==================================================
title "11. DISORDER KNOWN VALUES"
# ==================================================

$PS --bench 1 2 3 4 5 \
	>/dev/null 2>benchmark.tmp

if grep -Eq "Disorder:[[:space:]]*0\.00%" benchmark.tmp; then
	pass "sorted disorder = 0.00%"
else
	fail "sorted disorder should be 0.00%"
	cat benchmark.tmp
fi

$PS --bench 5 4 3 2 1 \
	>/dev/null 2>benchmark.tmp

if grep -Eq "Disorder:[[:space:]]*100\.00%" benchmark.tmp; then
	pass "reverse disorder = 100.00%"
else
	fail "reverse disorder should be 100.00%"
	cat benchmark.tmp
fi

rm -f benchmark.tmp

# ==================================================
title "12. RANDOM CORRECTNESS - ALL STRATEGIES"
# ==================================================

if [ -n "$TEST_CHECKER" ]; then

	for strategy in simple medium complex adaptive; do

		ok=1

		for i in $(seq 1 20); do

			ARG=$(shuf -i 0-20000 -n 100 | \
				awk '{print $1 - 10000}' | \
				tr '\n' ' ')

			RESULT=$($PS --$strategy $ARG | \
				$TEST_CHECKER $ARG)

			if [ "$RESULT" != "OK" ]; then
				ok=0
				break
			fi

		done

		if [ "$ok" -eq 1 ]; then
			pass "$strategy passed 20 random x100"
		else
			fail "$strategy failed random correctness"
		fi

	done
fi

# ==================================================
title "13. SAME INPUT - STRATEGY COMPARISON"
# ==================================================

if [ -n "$TEST_CHECKER" ]; then

	ARG=$(shuf -i 1-200 -n 50 | tr '\n' ' ')

	SIMPLE_COUNT=$($PS --simple $ARG | wc -l)
	MEDIUM_COUNT=$($PS --medium $ARG | wc -l)
	COMPLEX_COUNT=$($PS --complex $ARG | wc -l)
	ADAPTIVE_COUNT=$($PS --adaptive $ARG | wc -l)

	echo "simple   : $SIMPLE_COUNT"
	echo "medium   : $MEDIUM_COUNT"
	echo "complex  : $COMPLEX_COUNT"
	echo "adaptive : $ADAPTIVE_COUNT"

	for strategy in simple medium complex adaptive; do

		RESULT=$($PS --$strategy $ARG | \
			$TEST_CHECKER $ARG)

		if [ "$RESULT" = "OK" ]; then
			pass "$strategy valid on same 50-number input"
		else
			fail "$strategy invalid on same input"
		fi

	done

	if [ "$COMPLEX_COUNT" -lt "$SIMPLE_COUNT" ]; then
		pass "complex used fewer ops than simple"
	else
		warn "complex not better than simple on this random input"
	fi

fi

# ==================================================
title "14. PERFORMANCE - 100 NUMBERS"
# ==================================================

if [ -n "$TEST_CHECKER" ]; then

	for run in 1 2 3; do

		ARG=$(shuf -i 1-500 -n 100 | tr '\n' ' ')
		COUNT=$($PS $ARG | wc -l)
		RESULT=$($PS $ARG | $TEST_CHECKER $ARG)

		echo "run $run: $COUNT operations"

		if [ "$RESULT" != "OK" ]; then
			fail "100 elements run $run -> checker $RESULT"
		elif [ "$COUNT" -lt 700 ]; then
			pass "100 run $run EXCELLENT -> $COUNT"
		elif [ "$COUNT" -lt 1500 ]; then
			pass "100 run $run GOOD -> $COUNT"
		elif [ "$COUNT" -lt 2000 ]; then
			pass "100 run $run PASS -> $COUNT"
		else
			fail "100 run $run -> $COUNT operations"
		fi

	done
fi

# ==================================================
title "15. PERFORMANCE - 500 NUMBERS"
# ==================================================

if [ -n "$TEST_CHECKER" ]; then

	for run in 1 2; do

		ARG=$(shuf -i 1-1000 -n 500 | tr '\n' ' ')
		COUNT=$($PS $ARG | wc -l)
		RESULT=$($PS $ARG | $TEST_CHECKER $ARG)

		echo "run $run: $COUNT operations"

		if [ "$RESULT" != "OK" ]; then
			fail "500 elements run $run -> checker $RESULT"
		elif [ "$COUNT" -lt 5500 ]; then
			pass "500 run $run EXCELLENT -> $COUNT"
		elif [ "$COUNT" -lt 8000 ]; then
			pass "500 run $run GOOD -> $COUNT"
		elif [ "$COUNT" -lt 12000 ]; then
			pass "500 run $run PASS -> $COUNT"
		else
			fail "500 run $run -> $COUNT operations"
		fi

	done
fi

# ==================================================
title "16. CHECKER BASIC BEHAVIOR"
# ==================================================

if [ -x "$CHECKER" ]; then

	OUTPUT=$($CHECKER 2>&1)

	if [ -z "$OUTPUT" ]; then
		pass "checker no args -> no output"
	else
		fail "checker no args produced output"
	fi

	RESULT=$(printf "" | $CHECKER 0 1 2)

	if [ "$RESULT" = "OK" ]; then
		pass "checker sorted input -> OK"
	else
		fail "checker sorted input result: $RESULT"
	fi

	RESULT=$(printf "" | $CHECKER 3 2 1)

	if [ "$RESULT" = "KO" ]; then
		pass "checker unsorted input -> KO"
	else
		fail "checker unsorted input result: $RESULT"
	fi

fi

# ==================================================
title "17. CHECKER ERROR MANAGEMENT"
# ==================================================

if [ -x "$CHECKER" ]; then

	checker_error()
	{
		local label="$1"
		shift

		"$CHECKER" "$@" </dev/null \
			>/dev/null 2>error.tmp

		if grep -qx "Error" error.tmp; then
			pass "$label"
		else
			fail "$label"
		fi
	}

	checker_error "checker rejects duplicate" 1 2 2
	checker_error "checker rejects non numeric" 1 abc 3
	checker_error "checker rejects MAXINT overflow" 2147483648
	checker_error "checker rejects INT_MIN overflow" -2147483649

	printf "banana\n" | $CHECKER 3 2 1 \
		>/dev/null 2>error.tmp

	if grep -qx "Error" error.tmp; then
		pass "checker rejects invalid instruction"
	else
		fail "checker invalid instruction handling"
	fi

	printf " sa\n" | $CHECKER 3 2 1 \
		>/dev/null 2>error.tmp

	if grep -qx "Error" error.tmp; then
		pass "checker rejects leading-space instruction"
	else
		fail "checker accepts leading-space instruction"
	fi

	printf "sa \n" | $CHECKER 3 2 1 \
		>/dev/null 2>error.tmp

	if grep -qx "Error" error.tmp; then
		pass "checker rejects trailing-space instruction"
	else
		fail "checker accepts trailing-space instruction"
	fi

	rm -f error.tmp
fi

# ==================================================
title "18. CHECKER ALL 11 OPERATIONS"
# ==================================================

if [ -x "$CHECKER" ]; then

	ops=(
		"sa"
		"sb"
		"ss"
		"pa"
		"pb"
		"ra"
		"rb"
		"rr"
		"rra"
		"rrb"
		"rrr"
	)

	for op in "${ops[@]}"; do

		printf "%s\n" "$op" | \
			$CHECKER 2 1 \
			>/dev/null 2>error.tmp

		if [ ! -s error.tmp ]; then
			pass "checker accepts operation: $op"
		else
			fail "checker rejected valid operation: $op"
		fi

	done

	rm -f error.tmp
fi

# ==================================================
title "19. CHECKER EXACT EVALUATION KO TEST"
# ==================================================

if [ -x "$CHECKER" ]; then

	RESULT=$(
		printf "sa\npb\nrrr\n" |
		$CHECKER 0 9 1 8 2 7 3 6 4 5
	)

	if [ "$RESULT" = "KO" ]; then
		pass "evaluation KO test"
	else
		fail "evaluation KO test -> $RESULT"
	fi
fi

# ==================================================
title "20. CHECKER EXACT EVALUATION OK TESTS"
# ==================================================

if [ -x "$CHECKER" ]; then

	RESULT=$(printf "" | $CHECKER 0 1 2)

	if [ "$RESULT" = "OK" ]; then
		pass "evaluation sorted/no-instruction test"
	else
		fail "evaluation sorted test -> $RESULT"
	fi

	RESULT=$(
		printf "pb\nra\npb\nra\nsa\nra\npa\npa\n" |
		$CHECKER 0 9 1 8 2
	)

	if [ "$RESULT" = "OK" ]; then
		pass "evaluation exact checker OK sequence"
	else
		fail "evaluation exact checker sequence -> $RESULT"
	fi

fi

# ==================================================
title "21. CHECKER FLAG REJECTION"
# ==================================================

if [ -x "$CHECKER" ]; then

	for flag in --simple --medium --complex --adaptive --bench; do

		$CHECKER "$flag" 3 2 1 \
			</dev/null >/dev/null 2>error.tmp

		if grep -qx "Error" error.tmp; then
			pass "checker rejects $flag"
		else
			fail "checker incorrectly accepts $flag"
		fi

	done

	rm -f error.tmp
fi

# ==================================================
title "22. NORMINETTE"
# ==================================================

if command -v norminette >/dev/null; then

	NORM_OUTPUT=$(norminette . 2>&1)

	if echo "$NORM_OUTPUT" | grep -q "Error"; then
		fail "Norminette errors exist"
		echo "$NORM_OUTPUT" | grep "Error"
	else
		pass "Norminette"
	fi

else
	warn "norminette not installed - skipped"
fi

# ==================================================
title "23. VALGRIND PUSH_SWAP"
# ==================================================

if command -v valgrind >/dev/null; then

	valgrind \
		--leak-check=full \
		--show-leak-kinds=all \
		--errors-for-leak-kinds=all \
		--error-exitcode=42 \
		$PS --adaptive 5 8 -3 10 \
		>/dev/null 2>valgrind.tmp

	STATUS=$?

	if [ "$STATUS" -eq 42 ]; then
		fail "push_swap Valgrind"
		grep -E \
			"(definitely lost|indirectly lost|ERROR SUMMARY)" \
			valgrind.tmp
	else
		pass "push_swap Valgrind"
	fi

	rm -f valgrind.tmp

else
	warn "Valgrind not installed"
fi

# ==================================================
title "24. VALGRIND INVALID INPUT"
# ==================================================

if command -v valgrind >/dev/null; then

	valgrind \
		--leak-check=full \
		--show-leak-kinds=all \
		--errors-for-leak-kinds=all \
		--error-exitcode=42 \
		$PS 5 10 abc 3 \
		>/dev/null 2>valgrind.tmp

	STATUS=$?

	if [ "$STATUS" -eq 42 ]; then
		fail "push_swap invalid-input Valgrind"
	else
		pass "push_swap invalid-input Valgrind"
	fi

	rm -f valgrind.tmp
fi

# ==================================================
title "25. VALGRIND CHECKER"
# ==================================================

if command -v valgrind >/dev/null &&
	[ -x "$CHECKER" ]; then

	printf "sa\nrra\n" |
	valgrind \
		--leak-check=full \
		--show-leak-kinds=all \
		--errors-for-leak-kinds=all \
		--error-exitcode=42 \
		$CHECKER 3 2 1 \
		>/dev/null 2>valgrind.tmp

	STATUS=$?

	if [ "$STATUS" -eq 42 ]; then
		fail "checker Valgrind"
	else
		pass "checker Valgrind"
	fi

	rm -f valgrind.tmp
fi

# ==================================================
title "26. LIVE CODING DEFENSE REMINDER"
# ==================================================

echo
echo "Evaluator may ask you to add:"
echo
echo "    --count-only"
echo
echo "Example:"
echo "    ./push_swap --count-only 3 2 1"
echo
echo "Expected: only total operation count, no operations."
echo
echo "Evaluation sheet gives roughly 10 minutes."
echo

warn "live-coding modification cannot be automated safely"

# ==================================================
title "27. DEFENSE KNOWLEDGE CHECKLIST"
# ==================================================

echo
echo "[ ] Both learners present"
echo "[ ] Exactly 2 contributors"
echo "[ ] Both can explain any file"
echo "[ ] Explain Simple O(n²)"
echo "[ ] Explain Medium O(n√n)"
echo "[ ] Explain Complex O(n log n)"
echo "[ ] Explain Adaptive thresholds"
echo "[ ] Explain disorder / inversions"
echo "[ ] Explain assign_index"
echo "[ ] Explain all 11 operations"
echo "[ ] Explain stdout vs stderr benchmark"
echo "[ ] Explain top / bottom pointer updates"
echo "[ ] Explain why B must finish empty"

# ==================================================
title "FINAL RESULT"
# ==================================================

echo
echo -e "PASS: ${green}$PASS${reset}"
echo -e "FAIL: ${red}$FAIL${reset}"
echo -e "WARN: ${yellow}$WARN${reset}"

if [ "$FAIL" -eq 0 ]; then
	echo
	echo -e "${green}FULL AUTOMATED TEST SUITE PASSED${reset}"
else
	echo
	echo -e "${red}PROJECT STILL HAS FAILURES${reset}"
fi