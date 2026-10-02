# Anime checkpoint workflow validation

## Ready-to-use workflow

Load `user/default/workflows/anime_txt2img_compatible_validated.json` in ComfyUI.
It is a standard text-to-image graph with a real checkpoint filename, and the
checkpoint dropdown can be switched among these four tested files:

- `meinamix_v12Final.safetensors` (SD 1.5)
- `cyberrealisticXL_v100.safetensors` (SDXL)
- `babesByStableYogi_v65FP16.safetensors` (Pony XL)
- `rinIllusionRNSFW_v30.safetensors` (SDXL / Illustrious merge)

For a fast first run, keep 512x512 and 2-4 steps. Increase steps and resolution
after the first successful image.

The API-format version is `user/default/workflows/anime_txt2img_api_validated.json`.

The repaired original API workflow is `user/default/workflows/anime_txt2img_api_prompt.json`;
its checkpoint reference now points to `meinamix_v12Final.safetensors` instead of the
missing `MeinaMix_latest.safetensors`.

## Test evidence

All four checkpoints were queued through `POST /prompt` and completed with
`status_str=success`, producing one PNG each under `output/2026-07-29/validation/`:

- `meinamix_00001_.png`
- `cyberrealisticXL_v100_00001_.png`
- `babesByStableYogi_v65FP16_00001_.png`
- `rinIllusionRNSFW_00001_.png`

The repaired original API workflow also completed successfully with
`ComfyUI_Anime_00001_.png`.

## Anima checkpoint workflow

`nyaIrisAnima_base1V20.safetensors` is an Anima diffusion model and must not be
selected in `CheckpointLoaderSimple`. Load
`user/default/workflows/anime_txt2img_nya_anima_validated.json` instead. The
model must be available through `UNETLoader`, with these companion files:

- `nyaIrisAnima_base1V20.safetensors` in `models/diffusion_models`
- `qwen_3_06b_base.safetensors` in `models/text_encoders`
- `qwen_image_vae.safetensors` in `models/vae`

The Anima workflow uses `UNETLoader`, `CLIPLoader` with `type=stable_diffusion`,
and `VAELoader`. The first validation run uses 512x512 and 12 steps to keep VRAM
use reasonable on this RTX 2070; increase to 1024x1024 after it passes.

This layout follows the official ComfyUI Anima workflow and model installation
guide:

- https://github.com/Comfy-Org/workflow_templates/blob/main/templates/image_anima_base_v1.json
- https://huggingface.co/circlestone-labs/Anima

Anima validation evidence:

- API workflow: `ComfyUI_NyaAnima_Validated_00001_.png`, `status_str=success`
- UI workflow: `ComfyUI_NyaAnima_Validated_00002_.png`, completed from the ComfyUI Run button

No core ComfyUI code change was required: this installed ComfyUI version already
contains native Anima loader support. The existing `main(1).py` output-folder
customization was preserved.
