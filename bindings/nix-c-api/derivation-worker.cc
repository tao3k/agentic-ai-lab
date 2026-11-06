/* SPDX-FileCopyrightText: 2026 tao3k team and Contributors
 * SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
 */
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>
#include <vector>
#include <unistd.h>

#include <nix/expr/attr-path.hh>
#include <nix/store/globals.hh>
#include <nix/util/serialise.hh>
#include <nix_api_expr.h>
#include <nix_api_expr_internal.h>
#include <nix_api_store.h>

namespace {
constexpr std::size_t max_text = 1 << 20;
using Arguments = std::vector<std::pair<std::string, std::string>>;

// Observe the exact ordered configuration updates from Nix's own loader,
// including includes and overrides. Never apply them to the live Store.
struct ConfigurationCapture : nix::Config {
    Arguments entries;
    bool set(const std::string &name, const std::string &value) override
    {
        entries.emplace_back(name, value);
        return true;
    }
};

Arguments configuration()
{
    ConfigurationCapture capture;
    nix::loadConfFile(capture);
    return std::move(capture.entries);
}

void require_configuration(const Arguments &initial)
{
    if (configuration() != initial)
        throw std::runtime_error("Nix configuration changed during read-only evaluation");
}

std::string evaluate(nix_c_context *context, Store *store, const std::string &path,
                     const Arguments &arguments)
{
    // A fresh state reads current imports. Only the Store connection is shared.
    const std::unique_ptr<nix_eval_state_builder, decltype(&nix_eval_state_builder_free)>
        builder(nix_eval_state_builder_new(context, store), nix_eval_state_builder_free);
    if (!builder || nix_eval_state_builder_load(context, builder.get()) != NIX_OK)
        throw std::runtime_error("could not load Nix evaluation settings");
    if (const auto nix_path = std::getenv("NIX_PATH"))
        builder->settings.nixPath.override(nix::EvalSettings::parseNixPath(nix_path));
    const std::unique_ptr<EvalState, decltype(&nix_state_free)>
        owner(nix_eval_state_build(context, builder.get()), nix_state_free);
    if (!owner)
        throw std::runtime_error("could not create Nix EvalState");

    auto &state = owner->state;
    auto bindings = state.buildBindings(arguments.size());
    for (const auto &[name, value] : arguments)
        bindings.alloc(name).mkString(value, state.mem);
    auto &auto_args = *bindings.finish();
    nix::Value root;
    state.eval(state.parseExprFromFile(nix::resolveExprPath(state.rootPath(path))), root);
    auto &value = *nix::findAlongAttrPath(state, "drvPath", auto_args, root).first;
    state.forceValue(value, value.determinePos(nix::noPos));
    nix::Value result = value;
    if (!auto_args.empty())
        state.autoCallFunction(auto_args, value, result);
    nix::NixStringContext string_context;
    return std::string(*state.coerceToString(nix::noPos, result, string_context,
        "while generating the nix-instantiate output"));
}

std::string request_string(nix::FdSource &input, std::size_t &remaining)
{
    auto text = nix::readString(input, remaining);
    if (text.find('\0') != std::string::npos)
        throw std::invalid_argument("Nix request contains NUL");
    remaining -= text.size();
    return text;
}
}

int main()
{
    try {
        const auto initial_configuration = configuration();
        const std::unique_ptr<nix_c_context, decltype(&nix_c_context_free)>
            context(nix_c_context_create(), nix_c_context_free);
        if (!context || std::string_view(nix_version_get()) != LAB_NIX_VERSION ||
            nix_libexpr_init(context.get()) != NIX_OK)
            return 70;

        // Store registration consults this process-wide flag. The worker's
        // only operation is read-only evaluation, including between requests.
        nix::settings.readOnlyMode = true;
        // Use the configured Store just as the CLI does. Explicit "auto"
        // bypasses both the store setting and NIX_REMOTE.
        const std::unique_ptr<Store, decltype(&nix_store_free)>
            store(nix_store_open(context.get(), nullptr, nullptr), nix_store_free);
        if (!store)
            return 71;
        require_configuration(initial_configuration);

        nix::FdSource input(STDIN_FILENO);
        nix::FdSink output(STDOUT_FILENO);
        output << uint64_t{1};
        output.flush();
        while (true) {
            const auto operation = nix::readLongLong(input);
            if (operation == 0)
                return 0;
            if (operation != 1)
                return 65;
            std::size_t remaining = max_text;
            auto path = request_string(input, remaining);
            const auto count = nix::readInt(input);
            if (path.empty() || path == "-" || count > 128)
                return 65;
            Arguments arguments;
            arguments.reserve(count);
            for (unsigned int index = 0; index < count; ++index) {
                auto name = request_string(input, remaining);
                auto value = request_string(input, remaining);
                arguments.emplace_back(std::move(name), std::move(value));
            }
            std::string result;
            uint64_t status = 0;
            try {
                require_configuration(initial_configuration);
                result = evaluate(context.get(), store.get(), path, arguments);
                require_configuration(initial_configuration);
                if (result.size() > max_text)
                    throw std::runtime_error("Nix derivation response exceeds wire limit");
            } catch (const std::exception &error) {
                status = 1;
                result = std::string_view(error.what()).substr(0, max_text);
            }
            output << status << std::string_view(result);
            output.flush();
        }
    } catch (const std::exception &error) {
        std::fprintf(stderr, "Nix derivation worker: %s\n", error.what());
        return 70;
    }
}
