# Integer sequences
#
# This module is absolutely not meant to be exhausive.
# It should contain only those sequences that are frequently needed.

use v6.c;

unit module Math::Sequences::Integer is export;

class Integers is Range is export {
    multi method new(
            $min = -Inf,
            $max = Inf,
            :$excludes-min = True,
            :$excludes-max = True) {
        #Seems as if this doesn't get passed on correctly...
        #nextwith $min, $max, :$excludes-min, :$excludes-max
        self.Range::new($min, $max, :$excludes-min, :$excludes-max);
    }

    method is-default {
        self.min == -Inf and self.max == Inf and
            self.excludes-min and self.excludes-max;
    }

    method symbol { "ℤ" }
    method gist {
        if self.is-default {
            self.symbol;
        } else {
            my $emin = self.excludes-min ?? '^' !! '';
            my $emax = self.excludes-max ?? '^' !! '';
            "{self.^name}({self.min}{$emin}..{$emax}{self.max})"
        }
    }

    method !params {
        self.min.perl, self.max.perl,
            |(<excludes-min excludes-max>.map: -> $param {
                ":{$param}(" ~ self."$param"() ~ ')'
            });
    }

    method perl {
        "Integers.new(" ~ self!params.join(",") ~ ")"
    }

    method !min-countable {
        self.min.succ > self.min;
    }

    # An iterator based on the current range (full of fail)
    method iterator {
        class :: does Iterator {
            has $.min;
            has $.max;
            has $.offset;
            has $.countable;
            has $.endcmp;
            has $.cur = 0;

            method is-lazy()  { True  }

            method pull-one() {
                my $count = $!cur++;
                my $next = $!min + $count + $!offset;
                my $err = "Cannot count from non-finite starting point";
                my &endcmp = $!endcmp;

                if      endcmp($next, $!max)          { IterationEnd }
                elsif   $count == 0 and $!offset == 0 { $!min }
                elsif   ! $!countable                 { fail $err }
                else                                  { $next }
            }
        }.new(
            :min(self.min), :max(self.max),
            :countable(self!min-countable),
            :offset(self.excludes-min ?? 1 !! 0),
            :endcmp(self.excludes-max ?? {$^cur > $^end} !! {$^cur >= $^end}));
    }

    # All of the integers >= $n
    method from(Int $n) {
        my $min = $n;
        my $max = self.max;
        my $excludes-min = self.excludes-min;
        my $excludes-max = self.excludes-max;

        self.WHAT.new($min, $max, :$excludes-min, :$excludes-max);
    }

    method of { ::Int }
    method Numeric { Inf }
    method is-int { True }
    method infinite { True }
    method elems { Inf }
    method Str { self.gist }
}

# Naturals can mean 1..Inf or 0..Inf.
# For ease of naming, we define 𝕀 using Naturals and ℕ as the same
# sequence, counting from 1.
class Naturals is Integers is export {
    method new(
            $min = 0,
            $max = Inf,
            :$excludes-min = False,
            :$excludes-max = True) {
        nextwith $min, $max, :$excludes-min, :$excludes-max
    }

    method symbol { '𝕀' }
    method is-default {
        self.min == 0 and self.max == Inf and
            !self.excludes-min and self.excludes-max;
    }

    method from($n where * >= 0) { callsame }

    # Triangular counting
    method triangle {
        lazy gather for |self -> $n {
            for self.min .. $n -> $k {
                take ($n, $k);
            }
        }
    }
}

our constant \ℤ is export = Integers.new;
our constant \𝕀 is export = Naturals.new;
our constant \ℕ is export = 𝕀.from(1);

#####
# Utilities for the OEIS entires:

# via:
# https://github.com/perl6/perl6-examples/blob/master/categories/best-of-rosettacode/binomial-coefficient.pl
sub infix:<choose>($n, $p) is export(:support) { [*] ($n ... 0) Z/ 1 .. $p }
sub infix:<ichoose>($n,$p --> Int) is export(:support) { ($n choose $p).floor }

# Per OEIS A000111:
# 2*a(n+1) = Sum_{k=0..n} binomial(n, k)*a(k)*a(n-k).
sub euler-up-down($i is copy) is export(:support) {
    $i++;
    if $i < 2 {
        1
    } else {
        my $sum = [+] (0..$i).map: -> $k {
            ($i ichoose $k) * euler-up-down($k) * euler-up-down($i-$k) };
        $sum div 2;
    }
}

# Per OEIS A000123
sub binpart($n) { $n ?? binpart($n-1) + binpart($n div 2) !! 1 }

our %BROKEN = :A000111,;

sub factorial($n) is export(:support) { ([*] 1..$n) or 1 }

sub factors($n is copy, :%map) is export(:support) {
    gather do {
        if %map{$n}:exists {
            take %map{$n};
        } elsif $n < 4 {
            take $n;
        } else {
            .take for prime-factors($n);

            ### Inline factoring code from Perl 6 module Prime::Factor ########
            ### https://modules.perl6.org/search/?q=Prime+Factor
            ### Used with permission.

            sub prime-factors ( Int $n where * > 0 ) is export {
                return $n if $n.is-prime;
                return [] if $n == 1;
                my $factor = find-factor( $n );
                sort flat prime-factors( $factor ), prime-factors( $n div $factor );
            }

            sub find-factor ( Int $n, $constant = 1 ) {
                return 2 unless $n +& 1;
                # magic number below: product of primes 3 through 43
                if (my $gcd = $n gcd 6541380665835015) > 1 {
                    return $gcd if $gcd != $n
                }
                my $x      = 2;
                my $rho    = 1;
                my $factor = 1;
                while $factor == 1 {
                    $rho = $rho +< 1;
                    my $fixed = $x;
                    my int $i = 0;
                    while $i < $rho {
                        $x = ( $x * $x + $constant ) % $n;
                        $factor = ( $x - $fixed ) gcd $n;
                        last if 1 < $factor;
                        $i = $i + 1;
                    }
                }
                $factor = find-factor( $n, $constant + 1 ) if $n == $factor;
                $factor
            }

            ### End inlined code ###############################################
        }
    }
}

sub divisors($n) is export(:support) {
    gather do {
        take 1;
        if $n > 2 {
            for 2 .. ($n div 2) -> $i {
                take $i if $n %% $i;
            }
        }
        take $n if $n != 1;
    }
}

sub sigma($n, $exponent=1) is export(:support) {
    [+] divisors($n).map: -> $j { $j ** $exponent };
}

sub planar-partitions($n) is export(:support) {
    if $n <= 1 {
        1;
    } else {
        ([+] (1..$n).map: -> $k {
            planar-partitions($n-$k) * sigma($k, 2)
        }) div $n;
    }
}

#= The number of sequences that sum to $target where elements
#= <= $n and elements in each sum are distinct.
sub strict-partitions(Int:D $n, Int :$target=$n) is export(:support) {
    return strict-partitions($n.abs, :$target).map({.map: {-$_}}) if $n < 0;
    return [$n] if $n==0 and not $target;
    $target > 0 or die "\$target($target) cannot be < 0";
    gather for min($n,$target)...1 -> $i {
        given ($target)-$i -> $remain {
            when  $remain < 0 { next }
            when $remain == 0 { take [$i] }
            when      $i <= 1 { next } # only if $remain != 0 per above
            default {
                for strict-partitions($i-1, :target($remain)) -> $rest {
                    # Merge and add to results
                    take ($i, $rest).map: |*;
                }
            }
        }
    }
}

# https://mail.python.org/pipermail/edu-sig/2012-December/010721.html
sub Pi-digits is export(:support) {
    my ($q, $r, $t) = 1, 180, 60;
    gather for 2..* -> $j {
        my ($u,$y) =
            3*(3*$j+1)*(3*$j+2),
            ($q*(27*$j-12)+5*$r) div (5*$t);
        take $y;
        ($q, $r, $t) =
            10*$q*$j*(2*$j-1),
            10*$u*($q*(5*$j-2)+$r-$y*$t),
            $t*$u;
    }
}

# May as well, while we're here...
sub FatPi($digits=100) is export {
  FatRat.new(+([~] Pi-digits[^($digits)]), 10**($digits-1));
}

sub Horadam( Int $p, Int $q, Int $r, Int $s ) {
  my @horadam = $p, $q, {$^n1 × $r + $^n2 × $s} … ∞;
  return @horadam;
}


# If we don't yet have a formula for a given sequence, we use &NOSEQ in a
# range to define where our canned data ends. Because we use "fail", the
# failure only happens if you try to use a value past the end of our known
# entries.
sub NOSEQ { fail "This sequence has not yet been defined" }

# Needed for other sequences
our @A010051 is export = ℕ.map: { .is-prime ?? 1 !! 0 };
our @A080040 is export = 2, 2, -> $a, $b {2*$a + 2*$b} ... *;

# These are the "core" OEIS sequences as defined here:
# http://oeis.org/wiki/Index_to_OEIS:_Section_Cor
#

# groups
our @A000001 is export = 0, 1, 1, 1, 2, 1, 2, 1, 5, 2, 2, 1, &NOSEQ ... *;
# Kolakoski
our @A000002 is export = 1, 2, 2, -> $i {
    (state @a).push(|(((@a ?? @a[*-1] !! $i)%2+1) xx $i)); @a.shift} ... *;
# A000004 / 0's
our @A000004 is export = 0 xx *;
# A000005 / divisors
our @A000005 is export = ℕ.map: { divisors($^n).elems };
# A000007 / 0^n
our @A000007 is export = 𝕀.map: -> $n { 0 ** $n };
# A000009 / distinct partitions
our @A000009 is export = 𝕀.map: { strict-partitions($^i).elems };
# A000010 / totient
our @A000010 is export = (1..*).map: -> $t { +(^$t).grep: * gcd $t == 1 };
# A000012 / 1's
our @A000012 is export = 1 xx *;
# A000014 / series-reduced trees
our @A000014 is export = 0, 1, 1, 0, 1, 1, 2, 2, 4, 5, 10, 14, &NOSEQ ... *;
# A000019 / prim. perm. groups
our @A000019 is export = 1, 1, 2, 2, 5, 4, 7, 7, 11, 9, 8, 6, &NOSEQ ... *;
# A000027 / natural numbers
our @A000027 is export = |ℕ; # We chose 𝕀[0]=0, OEIS chose 𝕀[0]=1
# A000029 / necklaces
our @A000029 is export = 1, 2, 3, 4, 6, 8, 13, 18, 30, 46, 78, &NOSEQ ... *;
# A000031 / necklaces
our @A000031 is export = 1, 2, 3, 4, 6, 8, 14, 20, 36, 60, 108, &NOSEQ ... *;
# A000032 / Lucas
our @A000032 is export = 2, 1, * + * ... *;
our @sequence-Lucas is export =  @A000032;
# A000035 / 0101...
our @A000035 is export = |(0,1) xx *;
# A000040 / primes
our @A000040 is export = lazy 𝕀.grep: {.is-prime};
# A000041 / partitions
our @A000041 is export = 1, 1, 2, 3, 5, 7, 11, 15, 22, 30, 42, &NOSEQ ... *;
# A000043 / Mersenne
our @A000043 is export = lazy 𝕀.grep: { .is-prime and (2**$_-1).is-prime };
# A000045 / Fibonacci
our @A000045 is export = 0, 1, * + * ... *;
# A000048 / necklaces
our @A000048 is export = 1, 1, 1, 1, 2, 3, 5, 9, 16, 28, 51, &NOSEQ ... *;
# A000055 / trees
our @A000055 is export = 1, 1, 1, 1, 2, 3, 6, 11, 23, 47, 106, &NOSEQ ... *;
# A000058 / Sylvester
our @A000058 is export = 2, { $_**2 - $_ + 1 } ... *;
# A000069 / odious
our @A000069 is export = lazy 𝕀.grep: -> $n { ([+] $n.base(2).comb) !%% 2 };
# A000079 / 2^n
our @A000079 is export = 1, * * 2 ... *;
# A000081 / rooted trees
our @A000081 is export = 0, 1, 1, 2, 4, 9, 20, 48, 115, 286, &NOSEQ ... *;
# A000085 / self-inverse perms.
our @A000085 is export = 1, 1, -> $a,$b { state $n = 1; $b+($n++)*$a } ... *;
# A000088 / graphs
our @A000088 is export = 1, 1, 2, 4, 11, 34, 156, 1044, 12346, &NOSEQ ... *;
# A000105 / polyominoes
our @A000105 is export = 1, 1, 1, 2, 5, 12, 35, 108, 369, 1285, &NOSEQ ... *;
# A000108 / Catalan
our @A000108 is export = lazy 𝕀.map: {(2*$^n choose $^n)/($^n+1)};
# A000109 / polyhedra
our @A000109 is export = 1, 1, 1, 2, 5, 14, 50, 233, 1249, 7595, &NOSEQ ... *;
# A000110 / Bell
our @A000110 is export = 1, 1, 2, 5, 15, 52, 203, 877, 4140, &NOSEQ ... *;
# A000111 / Euler
our @A000111 is export = lazy 𝕀.map: -> $n {euler-up-down($n)};
# A000112 / posets
our @A000112 is export = 1, 1, 2, 5, 16, 63, 318, 2045, 16999, &NOSEQ ... *;
# A000120 / 1's in n
our @A000120 is export = lazy 𝕀.map: -> $n {$n.base(2).comb.grep({+$_}).elems};
# A000123 / binary partitions
our @A000123 is export = lazy 𝕀.map: &binpart;
# A000124 / Lazy Caterer
our @A000124 is export = lazy 𝕀.map: -> $n {($n * ($n+1)) / 2 + 1};
# A000129 / Pell
our @A000129 is export = 0, 1, * + 2 * * ... *;
our @Pell-sequence is export = @A000129;
# A000140 / Kendall-Mann
our @A000140 is export = 1, &NOSEQ ... *;
# A000142 / n!
our @A000142 is export = 𝕀.map: -> $n { factorial($n) };
# A000161 / partitions into 2 squares
our @A000161 is export = 1, &NOSEQ ... *;
# A000166 / derangements
our @A000166 is export = lazy 1, 0, -> $a, $b {state $n++; $n*($a + $n) } ... *;
# A000169 / labeled rooted trees
our @A000169 is export = lazy 1, {state $n++; $n**($n - 1) } ... *;
# A000182 / tangent
our @A000182 is export = 1, &NOSEQ ... *;
# A000203 / sigma
our @A000203 is export = ℕ.map: -> $n { sigma($n) };
# A000204 / Lucas
our @A000204 is export = 1, 3, *+* ... *;
# A000217 / triangular
our @A000217 is export = 𝕀.map: -> $n {($n*($n+1)) div 2};
# A000219 / planar partitions
our @A000219 is export = 𝕀.map: -> $n { planar-partitions($n) };
# A000225 / 2^n-1
our @A000225 is export = 𝕀.map: -> $n {2**$n-1};
# A000244 / 3^n
our @A000244 is export = 𝕀.map: -> $n {3**$n};
# A000262 / sets of lists
our @A000262 is export = 1, 1, -> $a, $b {state $n++; (2*($n+1)-1)*$b - $n*($n - 1) * $a } ... *;
# A000272 / n^(n-2)
our @A000272 is export = 𝕀.map: -> $n {$n ?? $n**($n-2) !! 1};
# A000273 / directed graphs
our @A000273 is export = 1, &NOSEQ ... *;
# A000290 / n^2
our @A000290 is export = 𝕀.map: -> $n {$n**2};
# A000292 / tetrahedral
our @A000292 is export = 𝕀.map: -> $n { ($n*($n+1)*($n+2)) div 6 };
# A000302 / 4^n
our @A000302 is export = 𝕀.map: -> $n {4**$n}
# A000311 / Schroeder's fourth
our @A000311 is export = 1, &NOSEQ ... *;
# A000312 / mappings
our @A000312 is export = 1, {state $n++; $n ** $n } ... *;
# A000326 / pentagonal
our @A000326 is export = 0, {state $n++; $n*(3*$n-1)/2 } ... *;
# A000330 / square pyramidal
our @A000330 is export = 0, {state $n++; $n*($n+1)*(2*$n+1)/6 } ... *;
# A000364 / Euler or secant
our @A000364 is export = 1, &NOSEQ ... *;
# A000396 / perfect
our @A000396 is export = lazy gather for @A000040 #`{primes} {
                             my $n = 2**$_ - 1;
                             take $n * 2**($_ - 1) if $n.is-prime;
                         }
# A000521 / j
our @A000521 is export = 1, &NOSEQ ... *;
# A000578 / n^3
our @A000578 is export = 𝕀.map: -> $n {$n ** 3}
# A000583 / n^4
our @A000583 is export = 𝕀.map: -> $n {$n ** 4}
# A000593 / sum odd divisors
our @A000593 is export = 1, {state $n++; sum $n.&divisors.grep: * % 2 } ... *;
# A000594 / Ramanujan tau
our @A000594 is export = 1, &NOSEQ ... *;
# A000602 / hydrocarbons
our @A000602 is export = 1, &NOSEQ ... *;
# A000609 / threshold functions
our @A000609 is export = 1, &NOSEQ ... *;
# A000670 / preferential arrangements
our @A000670 is export = 1, &NOSEQ ... *;
# A000688 / abelian groups
our @A000688 is export = 1, &NOSEQ ... *;
# A000720 / pi(n)
our @A000720 is export = [\+] @A010051;
# A000793 / Landau
our @A000793 is export = 1, &NOSEQ ... *;
# A000796 / Pi
our @A000796 is export = lazy Pi-digits;
# A000798 / quasi-orders or topologies
our @A000798 is export = 1, &NOSEQ ... *;
# A000959 / Lucky
our @A000959 is export = 1, &NOSEQ ... *;
# A000961 / prime powers
our @A000961 is export = 1, &NOSEQ ... *;
# A000984 / binomial(2n,n)
our @A000984 is export = 𝕀.map: -> $n {2*$n choose $n};
# A001003 / Schroeder's second problem
our @A001003 is export = 1, &NOSEQ ... *;
# A001006 / Motzkin
our @A001006 is export = 1, &NOSEQ ... *;
# A001034 / simple groups
our @A001034 is export = 1, &NOSEQ ... *;
# A001037 / irreducible polynomials
our @A001037 is export = 1, &NOSEQ ... *;
# A001045 / Jacobsthal
our @A001045 is export = 1, &NOSEQ ... *;
# A001055 / multiplicative partition function
our @A001055 is export = 1, &NOSEQ ... *;
# A001065 / sum of divisors
our @A001065 is export = ℕ.map: -> $n {
    [+] (1..^$n).grep: -> $i {$n %% $i};
}
# A001057 / all integers
our @A001057 is export = flat lazy gather for 𝕀 -> $n { take $n ?? ($n, -$n) !! 0 };
# A001097 / twin primes
our @A001097 is export = 𝕀.map({$_*2+1}).grep: { .is-prime and ($_+2 | $_-2).is-prime };
# A001113 / e
our @A001113 is export = 1, &NOSEQ ... *;
# A001147 / double factorials
our @A001147 is export = 1, 1, -> $a, $b { ($b/$a + 2) * $b } ... *;
# A001157 / sum of squares of divisors
our @A001157 is export = ℕ.map: -> $n {
    divisors($n).map(* ** 2).sum
}
# A001190 / Wedderburn-Etherington
our @A001190 is export = 1, &NOSEQ ... *;
# A001221 / omega
our @A001221 is export = ℕ.map: -> $n {
    $n >= 2 ?? factors($n).Set.keys.elems !! 0;
}
# A001222 / Omega
our @A001222 is export = ℕ.map: -> $n {
    $n >= 2 ?? factors($n, :map(1=>0)).elems !! 0;
}
# A001227 / odd divisors
our @A001227 is export = ℕ.map: -> $n {
    divisors($n).grep({$_ mod 2 == 1}).elems
}
# A001285 / Thue-Morse
our @A001285 is export = 1, &NOSEQ ... *;
# A001333 / sqrt(2)
our @A001333 is export = 1, &NOSEQ ... *;
# A001349 / connected graphs
our @A001349 is export = 1, &NOSEQ ... *;
# A001358 / semiprimes
our @A001358 is export = 𝕀.grep: -> $n {factors($n).elems == 2};
# A001405 / binomial(n,n/2)
our @A001405 is export = 𝕀.map: -> $n { $n choose ($n div 2) };
# A001462 / Golomb
our @A001462 is export = ℕ.map: -> $i {
    state @a;
    @a.push: |($i xx (@a ?? @a[0] !! $i));
    @a.shift;
}
# A001477 / integers
our @A001477 is export = 𝕀;
# A001478 / negatives
our @A001478 is export = ℕ.map: -> $n { -$n };
# A001481 / sums of 2 squares
our @A001481 is export = 1, &NOSEQ ... *;
# A001489 / negatives
our @A001489 is export = 𝕀.map: -> $n {-$n};
# A001511 / ruler function
our @A001511 is export = ℕ.map: -> $n { 1 + $n.base(2).flip.index('1') };
# A001615 / sublattices
our @A001615 is export = 1, &NOSEQ ... *;
# A001699 / binary trees
our @A001699 is export = 1, &NOSEQ ... *;
# A001700 / binomial(2n+1, n+1)
our @A001700 is export = 𝕀.map: -> $n { (2 * $n + 1) choose ($n + 1) };
# A001519 / Fib. bisection
our @A001519 is export = 1, &NOSEQ ... *;
# A001764 / binomial(3n,n)/(2n+1)
our @A001764 is export = 𝕀.map: -> $n { (3*$n choose $n)/(2*$n+1) };
# A001906 / Fib. bisection
our @A001906 is export = 1, &NOSEQ ... *;
# A001969 / evil
our @A001969 is export = 𝕀.grep: -> $n { $n.base(2).comb('1') %% 2 };
# A002033 / perfect partitions
our @A002033 is export = 1, &NOSEQ ... *;
# A002083 / Narayana-Zidek-Capell
our @A002083 is export = 1, &NOSEQ ... *;
# A002106 / transitive perm. groups
our @A002106 is export = 1, &NOSEQ ... *;
# A002110 / primorials
our @A002110 is export = flat 1, [\*] @A000040
# A002113 / palindromes
our @A002113 is export = 𝕀.grep: { $_ == .flip };
# A002275 / repunits
our @A002275 is export = 𝕀.map: -> $n { (10**$n - 1) div 9 };
# A002322 / psi
our @A002322 is export = 1, &NOSEQ ... *;
# A002378 / pronic
our @A002378 is export = 𝕀.map: -> $n { $n*($n+1) };
# A002426 / central trinomial coefficients
our @A002426 is export = 1, 1, -> $a, $b {
    (state $n = 1)++;
    ((3*($n-1))*$a+(2*$n-1)*$b) div $n;
} ... *;
# A002487 / Stern
our @A002487 is export = 𝕀.map: -> $n {
    my &a = &?BLOCK;
    my $h = $n div 2;
    $n < 2 ?? $n !! a($h) + ($n%%2 ?? 0 !! a($h+1));
}
# A002530 / sqrt(3)
our @A002530 is export = 0, |𝕀.map: -> $n {
    [+] (0..($n div 2)).map: -> $k {
        (($n-$k) choose $k) * 2**(($n - 2*$k) div 2);
    }
}
# A002531 / sqrt(3)
our @A002531 is export = @A080040 Z/ 𝕀.map: -> $n { (2*2**($n div 2)) }
# A002572 / binary rooted trees
our @A002572 is export = 1, &NOSEQ ... *;
# A002620 / quarter-squares
our @A002620 is export = 𝕀.map: -> $n { ($n**2 / 4).floor };
# A002654 / re: sums of squares
our @A002654 is export = 1, &NOSEQ ... *;
# A002658 / 3-trees
our @A002658 is export = lazy 1, 1, { @_[0 .. *-2].sum * @_.tail +  @_.tail * (@_.tail + 1) / 2 } ... *;
# A002808 / composites
our @A002808 is export = 𝕀.grep: -> $n {
    not $n.is-prime and factors($n).elems > 1;
}
# A003094 / connected planar graphs
our @A003094 is export = 1, &NOSEQ ... *;
# A003136 / Loeschian
our @A003136 is export = 1, &NOSEQ ... *;
# A003418 / LCM
our @A003418 is export = 𝕀.map: -> $n { [lcm] 1..$n };
# A003484 / Hurwitz-Radon
our @A003484 is export = 1, &NOSEQ ... *;
# A004011 / D_4
our @A004011 is export = 1, &NOSEQ ... *;
# A004018 / square lattice
our @A004018 is export = 1, &NOSEQ ... *;
# A004526 / ints repeated
our @A004526 is export = 𝕀.map: -> $n {$n div 2};
# A005036 / dissections
our @A005036 is export = 1, &NOSEQ ... *;
# A005100 / deficient
our @A005100 is export = ℕ.grep: -> $n { sigma($n) < 2 * $n };
# A005101 / abundant
our @A005101 is export = ℕ.grep: -> $n { sigma($n) > 2 * $n };
# A005117 / squarefree
our @A005117 is export  = ℕ.grep: { my @v = .&factors.Bag.values; @v.sum/@v <= 1 };
# A005130 / Robbins
our @A005130 is export = 1, -> $a {state $n++; $a * factorial($n) * factorial(3*$n+1) / factorial(2*$n) / factorial(2*$n+1) } ... *;
# A005230 / Stern
our @A005230 is export = 1, &NOSEQ ... *;
# A005408 / odd
our @A005408 is export = 𝕀.map: -> $n {$n*2+1};
# A005470 / planar graphs
our @A005470 is export = 1, &NOSEQ ... *;
# A005588 / binary rooted trees
our @A005588 is export = 1, &NOSEQ ... *;
# A005811 / runs in n
our @A005811 is export = 1, &NOSEQ ... *;
# A005843 / even
our @A005843 is export = 𝕀.map: -> $n {$n*2};
# A006318 / royal paths or Schroeder numbers
our @A006318 is export = 1, &NOSEQ ... *;
# A006530 / largest prime factor
our @A006530 is export = ℕ.map: -> $n {factors($n).max};
# A006882 / n!!
our @A006882 is export = 1, 1, -> $a, $b { (state $n = 2)++ * $a } ... *;
# A006894 / 3-trees
our @A006894 is export = 1, &NOSEQ ... *;
# A006966 / lattices
our @A006966 is export = 1, &NOSEQ ... *;
# A007318 / Pascal's triangle
our @A007318 is export = 𝕀.triangle.map: -> ($n,$k) { $n choose $k };
# A008275 / Stirling 1
our @A008275 is export = 1, &NOSEQ ... *;
# A008277 / Stirling 2
our @A008277 is export = 1, &NOSEQ ... *;
# A008279 / permutations k at a time
our @A008279 is export = 𝕀.triangle.map: -> ($n,$k) {
    factorial($n)/factorial($n-$k);
}
# A008292 / Eulerian
our @A008292 is export = |ℕ.triangle.map: -> ($n,$k) {
    [+] (0..$k).map: -> $j {
        (-1)**$j * ($k-$j)**$n * (($n+1) choose $j);
    }
}
# A008683 / Moebius
our @A008683 is export = 1, &NOSEQ ... *;
# A010060 / Thue-Morse
our @A010060 is export = 1, &NOSEQ ... *;
# A018252 / nonprimes
our @A018252 is export = ℕ.grep: {not .is-prime};
# A020639 / smallest prime factor
our @A020639 is export = ℕ.map: -> $n {factors($n).min};
# A020652 / fractal
our @A020652 is export = lazy gather for 2..* -> $de {
    for 1..^$de -> $nu {
        take $nu if ($nu/$de).numerator == $nu;
    }
}
# A020653 / fractal
our @A020653 is export = 1, 2, 1, 3, 1, 4, 3, 2, 1, 5, 1, 6, &NOSEQ ... *;
# A027641 / Bernoulli
our @A027641 is export = 1, -1, 1, 0, -1, 0, 1, 0, -1, 0, 5, &NOSEQ ... *;
# A027642 / Bernoulli
our @A027642 is export = 1, 2, 6, 1, 30, 1, 42, 1, 30, 1, 66, &NOSEQ ... *;
# A035099 / j_2
our @A035099 is export = 1, 40, 276, -2048, 11202, -49152, 184024, &NOSEQ ... *;
# A038566 / fractal
our @A038566 is export = 1, 1, 1, 2, 1, 3, 1, 2, 3, 4, 1, 5, &NOSEQ ... *;
# A038567 / fractal
our @A038567 is export = 1, 2, 3, 3, 4, 4, 5, 5, 5, 5, 6, 6, &NOSEQ ... *;
# A038568 / fractal
our @A038568 is export = 1, 1, 2, 1, 3, 2, 3, 1, 4, 3, 4, 1, &NOSEQ ... *;
# A038569 / fractal
our @A038569 is export = 1, 2, 1, 3, 1, 3, 2, 4, 1, 4, 3, 5, &NOSEQ ... *;
# A049310 / Chebyshev
our @A049310 is export = 𝕀.triangle.map: -> ($n, $k) {
    if $n < $k or ($n+$k) !%% 2 { 0 }
    else { ((-1)**(($n+$k)/2+$k)) * ((($n+$k)/2) choose $k) }
}
#T(n, k) := 0 if n<k or n+k odd, else ((-1)^((n+k)/2+k))*binomial((n+k)/2, k)
# A055512 / lattices
our @A055512 is export = 1, 1, 2, 6, 36, 380, 6390, 157962, 5396888, &NOSEQ ... *;
# A070939 / binary length
our @A070939 is export = 𝕀.map: { .base(2).chars };
# A074206 / ordered factorizations
our @A074206 is export = 0, 1, 1, 1, 2, 1, 3, 1, 4, 2, 3, 1, &NOSEQ ... *;
# A104725 / complementing systems
our @A104725 is export = 0, 1, 1, 1, 2, 1, 3, 1, 5, 2, 3, 1, &NOSEQ ... *;
# A226898 / Hooley's Delta
#our @A226898 is export = 1, &NOSEQ ... *;
our @A226898 is export = ℕ.map: -> $n {
    my @div = divisors($n);
    max(gather for 1..$n -> $u {
        take +@div.grep: -> $f { $f >= $u and $f <= $u*e };
    });
};
# A246655 / prime powers
our @A246655 is export = lazy gather for @A000040 -> $p {
    state @p;
    # Keep a list of each prime's infinite list of powers
    # [$p^1, $p^2, ...] and the current index
    @p.push: [(ℕ.map: {$p**$^power}),0];
    # Step through the prime powers until we hit $p
    loop {
        my $next = min(@p, :by({$^entry[0][$^entry[1]]}));
        my $value = $next[0][$next[1]];
        take $value;
        # Bumpt to next index
        $next[1]++;
        last if $value == $p;
    }
}

#Horadam sequences. Just the first 10
our @A085939 is export = Horadam( 0, 1, 6, 4);
our @A085449 is export = Horadam( 0, 1, 4, 2);
our @A085504 is export = Horadam( 0, 1, 9, 3);
our @A001076 is export = Horadam( 0, 1, 1, 4);

#Hofstadter sequences
our @A005206 is export = 0, {++$ - @A005206[@A005206[$++]]} … ∞;
our @A005374 is export = 0, {++$ - @A005374[@A005374[@A005374[$++]]]} … ∞;

## Aliases
our %oeis-core is export = (
    "groups" => @A000001,
    "kolakoski" => @A000002,
    "zeroes" => @A000004,
    "divisors" => @A000005,
    "zeros-powers" => @A000007,
    "distinct-partitions" => @A000009,
    "totient" => @A000010,
    "ones" => @A000012,
    "series-reduced-trees" => @A000014,
    "primitive-permutation-groups" => @A000019,
    "natural-numbers" => @A000027,
    "bracelets" => @A000029,
    "necklaces-two-color" => @A000031,
    "lucas" => @A000032,
    "fours-powers" => @A000302,
    "zero-one" => @A000035,
    "primes" => @A000040,
    "partitions" => @A000041,
    "mersennes" => @A000043,
    "fibonacci" => @A000045,
    "necklaces-two-color-interchangable" => @A000048,
    "trees" => @A000055,
    "sylvester" => @A000058,
    "odious" => @A000069,
    "twos-powers" => @A000079,
    "rooted-trees" => @A000081,
    "self-inverse-permutations" => @A000085,
    "graphs" => @A000088,
    "polyominoes" => @A000105,
    "catalan" => @A000108,
    "polyhedra" => @A000109,
    "bell" => @A000110,
    "euler" => @A000111,
    "posets" => @A000112,
    "ones-count" => @A000120,
    "binary-partitions" => @A000123,
    "lazy-caterer" => @A000124,
    "pell" => @A000129,
    "kendall-mann" => @A000140,
    "factorial" => @A000142,
    "partitions-two-squares" => @A000161,
    "derangements" => @A000166,
    "labeled-rooted-trees" => @A000169,
    "tangents" => @A000182,
    "sigma" => @A000203,
    "lucas-one-three" => @A000204,
    "triangular" => @A000217,
    "planar-partitions" => @A000219,
    "twos-powers-minus-one" => @A000225,
    "threes-powers" => @A000244,
    "sets-of-lists" => @A000262,
    "n-to-n-minus-two" => @A000272,
    "directed-graphs" => @A000273,
    "squares" => @A000290,
    "tetrahedral" => @A000292,
    "schroeders-fourth" => @A000311,
    "mappings" => @A000312,
    "pentagonal" => @A000326,
    "square-pyramidal" => @A000330,
    "euler-or-secant" => @A000364,
    "perfect" => @A000396,
    "coefficients-j-function" => @A000521,
    "cubes" => @A000578,
    "fourth-powers" => @A000583,
    "sum-odd-divisors" => @A000593,
    "ramanujan-tau" => @A000594,
    "hydrocarbons" => @A000602,
    "threshold-functions" => @A000609,
    "preferential-arrangements" => @A000670,
    "abelian-groups" => @A000688,
    "primes-less-than-n" => @A000720,
    "landau" => @A000793,
    "pi-digits" => @A000796,
    "quasi-orders" => @A000798,
    "lucky" => @A000959,
    "prime-powers-from-zero" => @A000961,
    "binomial-two-n-n" => @A000984,
    "schroeders-second-problem" => @A001003,
    "motzkin" => @A001006,
    "simple-groups" => @A001034,
    "irreducible-polynomials" => @A001037,
    "jacobsthal" => @A001045,
    "multiplicative-partition" => @A001055,
    "sum-of-divisors" => @A001065,
    "integers" => @A001057,
    "twin-primes" => @A001097,
    "e-digits" => @A001113,
    "double-factorials" => @A001147,
    "sum-of-squares-of-divisors" => @A001157,
    "wedderburn-etherington" => @A001190,
    "omega-distinct" => @A001221,
    "omega" => @A001222,
    "odd-divisors" => @A001227,
    "thue-morse-ones-twos" => @A001285,
    "root-two-numerators" => @A001333,
    "connected-graphs" => @A001349,
    "semiprimes" => @A001358,
    "binomial-n-n-over-two" => @A001405,
    "golomb" => @A001462,
    "integers-from-zero" => @A001477,
    "negative-integers" => @A001478,
    "square-sums" => @A001481,
    "negative-integers-from-zero" => @A001489,
    "ruler-function" => @A001511,
    "sublattices" => @A001615,
    "binary-trees" => @A001699,
    "binomial-two-n-plus-one-n-plus-one" => @A001700,
    "fibonacci-bisection" => @A001519,
    "binomial-three-n-n-over-two-n-plus-one" => @A001764,
    "fibonacci-bisection-sums" => @A001906,
    "evil" => @A001969,
    "perfect-partitions" => @A002033,
    "narayana-zidek-capell" => @A002083,
    "transitive-permutation-groups" => @A002106,
    "primorials" => @A002110,
    "palindromes" => @A002113,
    "repunits" => @A002275,
    "psi" => @A002322,
    "carmichael-lambda" => @A002322,
    "pronic" => @A002378,
    "central-trinomial-coefficients" => @A002426,
    "sterns-diatomic-series" => @A002487,
    "stern-brocot" => @A002487,
    "root-three-denominators" => @A002530,
    "root-three-numerators" => @A002531,
    "binary-rooted-trees" => @A002572,
    "quarter-squares" => @A002620,
    "n-as-sums-of-squares" => @A002654,
    "three-trees" => @A002658,
    "composites" => @A002808,
    "connected-planar-graphs" => @A003094,
    "loeschian" => @A003136,
    "lcm" => @A003418,
    "least-common-multiple" => @A003418,
    "hurwitz-radon" => @A003484,
    "theta-series-D_4-lattice" => @A004011,
    "square-lattice" => @A004018,
    "integers-from-zero-repeated" => @A004526,
    "dissections" => @A005036,
    "deficient" => @A005100,
    "abundant" => @A005101,
    "squarefree" => @A005117,
    "robbins" => @A005130,
    "stern" => @A005230,
    "odds" => @A005408,
    "planar-graphs" => @A005470,
    "binary-rooted-trees" => @A005588,
    "runs" => @A005811,
    "evens" => @A005843,
    "royal-paths" => @A006318,
    "schroeder-numbers" => @A006318,
    "largest-prime-factor" => @A006530,
    "double-factorial" => @A006882,
    "three-trees" => @A006894,
    "lattices" => @A006966,
    "pascals-triangle" => @A007318,
    "stirling-one" => @A008275,
    "stirling-two" => @A008277,
    "permutations-k-at-a-time" => @A008279,
    "eulerian" => @A008292,
    "moebius" => @A008683,
    "thue-morse" => @A010060,
    "nonprimes" => @A018252,
    "smallest-prime-factor" => @A020639,
    "bijection-integers-rationals-numerators-from-one" => @A020652,
    "bijection-integers-rationals-denominators-from-one" => @A020653,
    "bernoulli-numerators" => @A027641,
    "bernoulli-denominaotrs" => @A027642,
    "mckay-thompson" => @A035099,
    "bijection-integers-rationals-numerators-from-zero" => @A038566,
    "bijection-integers-rationals-denominators-from-zero" => @A038567,
    "bijection-integers-rationals-numerators-from-one-alt" => @A038568,
    "bijection-integers-rationals-denominators-from-one-alt" => @A038569,
    "chebyshev" => @A049310,
    "lattices-labeled" => @A055512,
    "binary-length" => @A070939,
    "ordered-factorizations" => @A074206,
    "complementing-systems" => @A104725,
    "hooleys-delta" => @A226898,
    "prime-powers" => @A246655,
    "horadam-0-1-6-4" => @A085939,
    "horadam-0-1-4-2" => @A085449,
    "horadam-0-1-9-3" => @A085504,
    "horadam-0-1-1-4" => @A001076,
    "hofstadters-g" => @A005206,
    "hofstadters-h" => @A005374
);

#={ OEIS "foo" will give the OEIS entry named or aliased foo
    OEIS "foo", :search will give a hash of all entries with
    labels that start with "foo"}
sub OEIS($name, Bool :$search=False) is export {
    sub A-entry($name) {
        given $name {
            when /^A\d+$/ {
                @::($name);
                CATCH { when X::NoSuchSymbol { .resume } }
            }
            default { Nil }
        }
    }
    if $search {
        my %matches = %oeis-core.pairs.grep: -> $kv { $kv.key.starts-with: $name };
        my $A-entry = A-entry $name;
        %matches{$name} //= $A-entry if $A-entry.defined;
        return %matches;
    } else {
        return A-entry($name) // %oeis-core{$name};
    }
}

# vim: sw=4 softtabstop=4 expandtab ai ft=perl6
