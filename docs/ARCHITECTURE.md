# nix-types — 架构与设计文档（无泛型版本）

## 1. 项目意图

`nix-types` 是一个 **纯 Nix builtins** 实现的类型系统库，专注于 **代数数据类型（ADT / Sum Type）** 与 **模式匹配（pattern matching）**，适合在 Nix 配置中声明领域模型、状态机、校验器与受控的 ADT 值。

### 设计目标

- **零依赖**：仅使用 Nix 语言内置函数（`builtins.*`），不依赖 `nixpkgs` 或任何 flake input。
- **安全**：所有公共入口都有强校验；错误信息可读、可定位；用 `builtins.seq` 保证错误严格触发。
- **现代**：使用 `|>` 管道操作符、`@` 模式绑定、`rec` 闭包等现代 Nix 语法；模块分层清晰。
- **高效**：避免重复计算；使用 `builtins.foldl'` 严格折叠；构造器惰性分派。
- **调用方书写方式不变**：保留原始 `enum "T" [...]` / `enum "T" {...}` / `T.match ...` / `types.fn-isXxx` 等 API。

### 与原版差异

移除了 **泛型（generic types）** 相关的所有内容：

| 删除 | 原因 |
|------|------|
| `enum "Foo<T,R>" {...}` 解析 | 不需要参数化类型 |
| `Foo Color Shape Position` 实例化 | 不需要类型参数 |
| `__isGeneric__` / `__genericParams__` / `__arity__` / `__functor` / `instantiate` | 泛型基础设施 |
| `types.fn-isGeneric` / `types.fn-isGenericInst` | 泛型谓词 |
| `types.EnumGenericTypeStruct` | 泛型类型结构 |
| `validators.generic.*` | 泛型校验器 |
| `fn-mkGeneric*` 系列 | 泛型实例化逻辑 |

保留 **非泛型类型设计** 的全部能力：

| 保留 | 用途 |
|------|------|
| 单元枚举 `enum "Color" ["Red" "Green" "Blue"]` | 简单选择类型 |
| Postable 枚举 `enum "Shape" { Circle=Color; Square=[Color Color Color]; Triangle={...}:fn; }` | 携带值的变体 |
| 字面量变体（int/float/bool/null/string/path） | 配置常量 |
| 元组变体 `[T1 T2 T3]` | 位置参数 |
| 函数校验器变体 `{pos1,pos2,...}@inst: fn` | 自定义校验 |
| `T.match inst { Red=...; _=...; }` | 单实例匹配 |
| `T.match [c1 c2 c3] { Red.Circle.local={_1,_2,_3}:...; _._._=...; }` | 多实例列表匹配 |
| `T.match { inherit c1 c2 c3; } { __PORDER__=[...]; Red.Circle.local=...; }` | 多实例 attrset 匹配（带顺序） |
| `types.fn-isEnum/fn-isInst/fn-isType/fn-descTp` | 类型自省 |
| `T.serialize inst` | 序列化为 `{tag,type,value}` |
| 严格错误信息 | 校验失败时给出可读诊断 |

---

## 2. 分层架构

```
lib/enum/default.nix
├── LAYER 0: config          — 配置与常量
├── LAYER 1: lib             — 核心工具库（字符串、列表、attrset 辅助）
├── LAYER 2: types           — 类型谓词与描述符
├── LAYER 3: validators      — 校验层（types/postable/fn/match）
├── LAYER 4: constructors    — 变体实例构造器
├── LAYER 5: match           — 模式匹配引擎
└── LAYER 6: factory         — 公共 enum 工厂入口
```

### 各层职责

- **LAYER 0 config**：所有常量集中管理，避免散落的魔术字符串。
- **LAYER 1 lib**：纯函数工具集，不引用其他层，可独立测试。
- **LAYER 2 types**：类型谓词（`fn-isEnum`、`fn-isInst`、`fn-isType`、`fn-descTp`）和结构定义（`EnumInstMeta`、`EnumInstStruct`、`VariantInstValueBase` 等）。
- **LAYER 3 validators**：所有 `throw` 集中在此层，错误信息格式化、上下文信息、嵌套诊断。
- **LAYER 4 constructors**：将 enum 定义编译为可调用的构造器（每个变体对应一个 lambda）。
- **LAYER 5 match**：模式匹配引擎，支持单匹配、多匹配、`__PORDER__`、通配符 `_`、特异性排序。
- **LAYER 6 factory**：`enum` 入口，分派到 tuple-enum 或 postable-enum 构造路径。

### 数据流

```
[调用方] enum "Shape" { Circle=Color; ... }
   │
   ▼
[factory] fn-mkEnumDispatcher
   │  (校验 variants 类型)
   ▼
[constructors] fn-mkEnumInstStructPostableVariants
   │  (为每个 variant 生成分派构造器)
   ▼
[types.EnumTypeFuncs] { __typename__, __meta__, __variants__, match, serialize, <variants>... }
   │
   ▼
[调用方] Shape.Circle Color.Red
   │
   ▼
[constructors] fn-postableDispatchConstructor → fn-postableEnumConstructor
   │  (校验 arg 是 Color 的实例)
   ▼
[types.VariantInstValueBase] { tag, type, value, toString, __IS_ENUM_INSTANCE_MASKER_V1__ }
```

---

## 3. 调用方 API（不变）

```nix
{ enum, types, lib, ... }:

let
  # 1) 单元枚举
  Color = enum "Color" [ "Red" "Green" "Blue" ];
  cg = Color.Green;
  rc-cg = Color.match cg {
    Red   = v: "enum::Color::${v.tag}";
    Green = v: "enum::Color::${v.tag}";
    Blue  = v: "enum::Color::${v.tag}";
  };

  # 2) Postable 枚举
  validator_func = { pos1, pos2, pos3, ... }:
    if pos1.tag == pos2.tag
      then { inherit pos1 pos2 pos3; }
    else { __throw = "Expected pos1 == pos2, found `${pos1.tag} != ${pos2.tag}`"; };

  Shape = enum "Shape" {
    Circle    = Color;
    Square    = [ Color Color Color ];
    Triangle  = { pos1, pos2, pos3 }@instance: validator_func instance;
    Rhombus   = { pos1, pos2, pos3, ... }@instance: validator_func instance;
  };

  sc = Shape.Circle Color.Red;
  ss = Shape.Square [ Color.Red Color.Green Color.Blue ];
  st = Shape.Triangle { pos1=Color.Red; pos2=Color.Red; pos3=Color.Blue; };

  rs-sc = Shape.match sc {
    Circle = v: "enum::Shape::${v.tag}";
    _      = v: "Other: ${v.tag}";
  };

  # 3) 多实例匹配（列表）
  color = Color.Red; shape = Shape.Circle Color.Red;
  rs-gps = Shape.match [ color shape ] {
    Red.Circle = { _1, _2 }: "${_1.tag}, ${_2.tag}";
    _._        = { ... }: 0;
  };

  # 4) 多实例匹配（attrset + __PORDER__）
  rs-gpsd = Shape.match { inherit color shape; } {
    __PORDER__ = [ "color" "shape" ];
    Red.Circle = { color, shape }: "${color.tag}, ${shape.tag}";
    _._        = { ... }: 0;
  };

  # 5) 字面量与混合变体
  Drive = enum "Drive" {
    self         = Color.Red;
    intel        = "intel";
    nvidia       = "nvidia";
    intel-nvidia = [ "intel" "nvidia" ];
  };

  # 6) 类型自省
  is-enum  = types.fn-isEnum Shape;
  is-inst  = types.fn-isInst sc;
  is-type  = types.fn-isType sc Shape;          # true
  desc     = types.fn-descTp sc;                # "enum::Shape::Circle(enum::Color::Red)"
  ser      = Shape.serialize sc;                # { tag="Circle"; type=...; value=...; }
in { ... }
```

---

## 4. 测试标准化

测试结构：

```
test/
├── default.nix          # 测试入口：聚合所有模块、生成总结
├── framework.nix        # 测试小框架：run / runAll / assertXxx
└── enum/
    └── default.nix      # 枚举所有用例，按 feature 分组
```

### 测试框架设计

```nix
# test/framework.nix
{ run = name: thunk:              # 运行单个测试，捕获异常
    let r = builtins.tryEval (builtins.seq thunk true);
    in { inherit name; ok = r.success;
         error = if r.success then null else (toString r.value); };

  runAll = cases:                 # 运行用例列表，统计 pass/fail
    let results = map (c: run c.name c.test) cases;
        pass = builtins.filter (r: r.ok) results;
        fail = builtins.filter (r: !r.ok) results;
    in { total   = builtins.length results;
         passed  = builtins.length pass;
         failed  = builtins.length fail;
         failures = fail;
         allPassed = builtins.length fail == 0; };

  assertEqual = name: a: b: a == b;
  assertTrue  = name: v: v == true;
}
```

### 测试用例分组

- `unit.*` — 单元枚举：创建、匹配、序列化
- `postable.literal.*` — 字面量变体（int/float/bool/null/string/path）
- `postable.enum.*` — 枚举类型变体
- `postable.tuple.*` — 元组变体
- `postable.fun.*` — 函数校验器变体（含 `__throw` 错误路径）
- `postable.mixed.*` — 混合变体（如 Drive）
- `match.single.*` — 单实例匹配（含通配符）
- `match.list.*` — 多实例列表匹配（特异性排序）
- `match.attrset.*` — attrset 匹配（`__PORDER__`）
- `match.exhaust.*` — 非穷尽匹配错误用例
- `types.*` — 类型谓词（`fn-isEnum/fn-isInst/fn-isType/fn-descTp`）
- `serialize.*` — 序列化

### 测试运行方式

```bash
# 1) 全部测试，打印总结
nix eval --impure --file ./test/default.nix

# 2) 只看是否通过（exit code 0 = 全过）
nix eval --impure --file ./test/default.nix allPassed --raw && echo OK

# 3) 查看失败用例
nix eval --impure --file ./test/default.nix failures --json
```
