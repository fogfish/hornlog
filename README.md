# hornlog

The library provide a primitives to define and evaluate horn clauses. The library implement a translation of logic program into executable code using pattern matching technique for evaluation.

```
u <- (p ^ q ^ ... ^ t)
``` 

## rules

The rule is defined as implication clause `[p, q, ..., t]`. The rule is true if input pattern is matched. The library uses `'_'` to match any term (e.g. `[p, '_', ..., t]`).   

There are three type of rules: headless, identity and augmented. The _headless_ rule return input subject if pattern is matched `hornlog:rule([p, q, ..., t])`. The _identity_ rule curry term to identity function and return this value with curried value if pattern is matched `hornlog:rule(hornlog:id(u), [p, q, ..., t])`. The _augmented_ rule curries terms to any external function, which is called if pattern is matched `hornlog:rule(hornlog:head(fun myapp:u/2, [u]), [p, q, ..., t])`.

## compile and evaluate 

The rule compiler transforms set of rules into executable program, which is loaded and manged by Erlang code server `hornlog:c(my_rule_test, [...])`.
  

The rules evaluation process takes two arguments: pattern (feature vector) and subject. The feature vector is matched against previously defined pattern. The subject is feed to head function if pattern matches the rule `hornlog:q(my_rule_test, [p, q, ..., t], {...})`.
 
## example

Classical play tennis example from Machine Learning books. The feature vector consists of outlook, temperature, humidity, wind.

```
hornlog:c(play_tennis, [
   hornlog:rule(hornlog:id(true),  [overcast, hot,  high, weak]),
   hornlog:rule(hornlog:id(true),  [overcast, cool, low,  strong]),
   hornlog:rule(hornlog:id(true),  [overcast, mild, high, strong]),
   hornlog:rule(hornlog:id(true),  [overcast, hot,  low,  weak]),

   hornlog:rule(hornlog:id(false), [rainy,    cool, low,  strong]),
   hornlog:rule(hornlog:id(false), [rainy,    mild, high, strong]),
   hornlog:rule(hornlog:id(true),  [rainy,    mild, high, weak]),
   hornlog:rule(hornlog:id(true),  [rainy,    cool, low,  weak]),
   hornlog:rule(hornlog:id(true),  [rainy,    mild, low,  weak]),

   hornlog:rule(hornlog:id(false), [sunny,    hot,  high, weak]),
   hornlog:rule(hornlog:id(false), [sunny,    hot,  high, strong]),
   hornlog:rule(hornlog:id(false), [sunny,    mild, high, weak]),
   hornlog:rule(hornlog:id(true),  [sunny,    cool, low,  weak]),
   hornlog:rule(hornlog:id(true),  [sunny,    mild, low,  strong])
]).


hornlog:q(play_tennis, [rainy, cool, low, weak], me).
```

